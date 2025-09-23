#!/bin/bash

# Script to convert Resume_Siegel.html to resume_siegel.pdf
# Runs until successful conversion

INPUT_FILE="Resume_Siegel.html"
OUTPUT_FILE="resume_siegel.pdf"

echo "Converting $INPUT_FILE to $OUTPUT_FILE..."

# Function to try wkhtmltopdf
try_wkhtmltopdf() {
    echo "Trying wkhtmltopdf..."
    if wkhtmltopdf --page-size A4 --margin-top 0.75in --margin-right 0.75in --margin-bottom 0.75in --margin-left 0.75in "$INPUT_FILE" "$OUTPUT_FILE" 2>/dev/null; then
        echo "Success with wkhtmltopdf!"
        return 0
    else
        echo "wkhtmltopdf failed"
        return 1
    fi
}

# Function to try Chrome headless
try_chrome() {
    echo "Trying Chrome headless..."
    if /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --headless --disable-gpu --print-to-pdf="$OUTPUT_FILE" --virtual-time-budget=2000 "file://$(pwd)/$INPUT_FILE" 2>/dev/null; then
        echo "Success with Chrome!"
        return 0
    else
        echo "Chrome failed"
        return 1
    fi
}

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found!"
    exit 1
fi

# Keep trying until success
attempt=1
while true; do
    echo "Attempt #$attempt"
    
    # Remove existing PDF if it exists to start fresh
    [ -f "$OUTPUT_FILE" ] && rm "$OUTPUT_FILE"
    
    # Try wkhtmltopdf first
    if try_wkhtmltopdf; then
        break
    fi
    
    # If wkhtmltopdf fails, try Chrome
    if try_chrome; then
        break
    fi
    
    echo "Both methods failed. Retrying in 2 seconds..."
    sleep 2
    ((attempt++))
done

# Verify the PDF was created and has content
if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    echo "PDF created successfully: $OUTPUT_FILE"
    ls -lh "$OUTPUT_FILE"
else
    echo "Error: PDF was not created properly"
    exit 1
fi