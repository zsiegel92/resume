#!/usr/bin/env tsx

import * as fs from "node:fs";
import * as path from "node:path";
import { pathToFileURL } from "node:url";
import puppeteer from "puppeteer";

const INPUT_FILE = "resume_siegel.html";
const OUTPUT_FILE = "resume_siegel.pdf";
const PAPER_WIDTH = "8.5in";
const PAPER_HEIGHT = "14.3in";
const PDF_MARGIN = "0in";
const PDF_SCALE = 1;
const PDF_TIMEOUT_MS = 60_000;
const CHROME_EXECUTABLE: string | undefined = undefined;
const CHROME_EXECUTABLE_CANDIDATES = [
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  path.join(
    process.env.HOME || "",
    "Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  ),
  "/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta",
  "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
];

function paperToCssPixels(value: string): number {
  const match = value.trim().match(/^([0-9]*\.?[0-9]+)\s*(in|cm|mm|px)?$/i);
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

function findChromeExecutable(): string | undefined {
  if (CHROME_EXECUTABLE) {
    return CHROME_EXECUTABLE;
  }

  return CHROME_EXECUTABLE_CANDIDATES.find(
    (candidate) => candidate && fs.existsSync(candidate),
  );
}

async function main(): Promise<void> {
  const inputPath = path.resolve(INPUT_FILE);
  const outputPath = path.resolve(OUTPUT_FILE);
  const tempOutputPath = `${outputPath}.tmp-${process.pid}.pdf`;

  if (!fs.existsSync(inputPath)) {
    throw new Error(`input file not found: ${INPUT_FILE}`);
  }

  const chromeExecutable = findChromeExecutable();
  const browser = await puppeteer.launch({
    ...(chromeExecutable ? { executablePath: chromeExecutable } : {}),
    headless: true,
    args: [
      "--allow-file-access-from-files",
      "--disable-gpu",
      "--no-default-browser-check",
      "--no-first-run",
    ],
  });

  const failedRequests: string[] = [];

  try {
    const page = await browser.newPage();
    page.setDefaultNavigationTimeout(PDF_TIMEOUT_MS);
    page.setDefaultTimeout(PDF_TIMEOUT_MS);

    await page.setViewport({
      width: paperToCssPixels(PAPER_WIDTH),
      height: paperToCssPixels(PAPER_HEIGHT),
      deviceScaleFactor: 1,
    });

    page.on("requestfailed", (request) => {
      failedRequests.push(
        `${request.url()} (${request.failure()?.errorText || "failed"})`,
      );
    });

    await page.goto(pathToFileURL(inputPath).href, {
      waitUntil: ["load", "networkidle0"],
      timeout: PDF_TIMEOUT_MS,
    });

    await page.emulateMediaType("print");
    await page.evaluateHandle("document.fonts.ready").catch(() => undefined);

    await page.pdf({
      path: tempOutputPath,
      width: PAPER_WIDTH,
      height: PAPER_HEIGHT,
      margin: {
        top: PDF_MARGIN,
        right: PDF_MARGIN,
        bottom: PDF_MARGIN,
        left: PDF_MARGIN,
      },
      printBackground: true,
      preferCSSPageSize: false,
      displayHeaderFooter: false,
      scale: PDF_SCALE,
      tagged: true,
    });

    const { size } = fs.statSync(tempOutputPath);
    if (size === 0) {
      throw new Error("Chrome generated an empty PDF");
    }

    fs.renameSync(tempOutputPath, outputPath);

    console.log(`Created ${path.relative(process.cwd(), outputPath) || outputPath}`);
    console.log(`Paper: ${PAPER_WIDTH} x ${PAPER_HEIGHT}; margins: ${PDF_MARGIN}; scale: ${PDF_SCALE}`);
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
}

main().catch((error: unknown) => {
  if (error instanceof Error) {
    console.error(error.stack || error.message);
  } else {
    console.error(String(error));
  }
  process.exit(1);
});
