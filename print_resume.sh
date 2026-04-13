#!/usr/bin/env bash
set -euo pipefail

# Print the resume HTML to PDF using Chrome's native print-to-PDF engine.
# This avoids AppleScript and the macOS print dialog entirely.

usage() {
  cat <<'EOF'
Usage:
  ./print_resume.sh [input.html] [output.pdf]

Defaults:
  input.html   resume_siegel.html
  output.pdf   resume_siegel.pdf

Environment overrides:
  PAPER_WIDTH=8.5in       PDF paper width
  PAPER_HEIGHT=14.5in     PDF paper height
  PDF_MARGIN=0in          PDF margins on all sides
  PDF_SCALE=1             Chrome print scale
  CHROME_EXECUTABLE=...   Chrome executable to use instead of auto-detect

Example:
  ./print_resume.sh
  PAPER_HEIGHT=14in ./print_resume.sh resume_siegel.html resume_siegel.pdf
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

INPUT_FILE="${1:-resume_siegel.html}"
OUTPUT_FILE="${2:-resume_siegel.pdf}"

if [[ ! -f "$INPUT_FILE" ]]; then
  echo "Error: input file not found: $INPUT_FILE" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Error: node is required. Install dependencies with npm install." >&2
  exit 1
fi

node - "$INPUT_FILE" "$OUTPUT_FILE" <<'NODE'
const fs = require("fs");
const path = require("path");
const { pathToFileURL } = require("url");

let puppeteer;
try {
  puppeteer = require("puppeteer");
} catch (error) {
  console.error("Error: puppeteer is not installed. Run: npm install");
  process.exit(1);
}

const [inputArg, outputArg] = process.argv.slice(2);
const inputPath = path.resolve(inputArg);
const outputPath = path.resolve(outputArg);
const tempOutputPath = `${outputPath}.tmp-${process.pid}.pdf`;

const paperWidth = process.env.PAPER_WIDTH || "8.5in";
const paperHeight = process.env.PAPER_HEIGHT || "14.5in";
const pdfMargin = process.env.PDF_MARGIN || "0in";
const pdfScale = Number(process.env.PDF_SCALE || "1");
const timeoutMs = Number(process.env.PDF_TIMEOUT_MS || "60000");

function paperToCssPixels(value) {
  const match = String(value).trim().match(/^([0-9]*\.?[0-9]+)\s*(in|cm|mm|px)?$/i);
  if (!match) {
    throw new Error(`Unsupported paper dimension: ${value}`);
  }

  const amount = Number(match[1]);
  const unit = (match[2] || "in").toLowerCase();

  switch (unit) {
    case "in":
      return Math.round(amount * 96);
    case "cm":
      return Math.round((amount / 2.54) * 96);
    case "mm":
      return Math.round((amount / 25.4) * 96);
    case "px":
      return Math.round(amount);
    default:
      throw new Error(`Unsupported paper unit: ${unit}`);
  }
}

function findChromeExecutable() {
  if (process.env.CHROME_EXECUTABLE) {
    return process.env.CHROME_EXECUTABLE;
  }

  const candidates = [
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    path.join(process.env.HOME || "", "Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
    "/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta",
    "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
  ];

  return candidates.find((candidate) => candidate && fs.existsSync(candidate));
}

(async () => {
  if (!Number.isFinite(pdfScale) || pdfScale <= 0) {
    throw new Error(`PDF_SCALE must be a positive number; got ${process.env.PDF_SCALE}`);
  }

  const chromeExecutable = findChromeExecutable();
  const launchOptions = {
    headless: true,
    args: [
      "--allow-file-access-from-files",
      "--disable-gpu",
      "--no-default-browser-check",
      "--no-first-run",
    ],
  };

  if (chromeExecutable) {
    launchOptions.executablePath = chromeExecutable;
  }

  const browser = await puppeteer.launch(launchOptions);
  const failedRequests = [];

  try {
    const page = await browser.newPage();
    page.setDefaultNavigationTimeout(timeoutMs);
    page.setDefaultTimeout(timeoutMs);

    await page.setViewport({
      width: paperToCssPixels(paperWidth),
      height: paperToCssPixels(paperHeight),
      deviceScaleFactor: 1,
    });

    page.on("requestfailed", (request) => {
      failedRequests.push(`${request.url()} (${request.failure()?.errorText || "failed"})`);
    });

    await page.goto(pathToFileURL(inputPath).href, {
      waitUntil: ["load", "networkidle0"],
      timeout: timeoutMs,
    });

    await page.emulateMediaType("print");
    await page.evaluateHandle("document.fonts.ready").catch(() => undefined);

    await page.pdf({
      path: tempOutputPath,
      width: paperWidth,
      height: paperHeight,
      margin: {
        top: pdfMargin,
        right: pdfMargin,
        bottom: pdfMargin,
        left: pdfMargin,
      },
      printBackground: true,
      preferCSSPageSize: false,
      displayHeaderFooter: false,
      scale: pdfScale,
      tagged: true,
    });

    const { size } = fs.statSync(tempOutputPath);
    if (size === 0) {
      throw new Error("Chrome generated an empty PDF");
    }

    fs.renameSync(tempOutputPath, outputPath);

    console.log(`Created ${path.relative(process.cwd(), outputPath) || outputPath}`);
    console.log(`Paper: ${paperWidth} x ${paperHeight}; margins: ${pdfMargin}; scale: ${pdfScale}`);
    console.log(`Chrome: ${chromeExecutable || puppeteer.executablePath()}`);

    if (failedRequests.length > 0) {
      console.warn("Warning: some page resources failed to load:");
      for (const failedRequest of failedRequests.slice(0, 5)) {
        console.warn(`  - ${failedRequest}`);
      }
      if (failedRequests.length > 5) {
        console.warn(`  - ...and ${failedRequests.length - 5} more`);
      }
    }
  } finally {
    await browser.close();
    fs.rmSync(tempOutputPath, { force: true });
  }
})().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(1);
});
NODE
