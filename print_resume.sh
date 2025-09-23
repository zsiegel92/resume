#!/bin/bash

# Script to automatically print Resume to PDF using AppleScript automation

INPUT_FILE="Resume_Siegel.html"
OUTPUT_FILE="resume_siegel.pdf"

echo "Converting $INPUT_FILE to $OUTPUT_FILE using AppleScript..."

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: $INPUT_FILE not found!"
    exit 1
fi

# Remove existing PDF
[ -f "$OUTPUT_FILE" ] && rm "$OUTPUT_FILE"

# Get the full path to the HTML file and output file
FULL_PATH="file://$(pwd)/$INPUT_FILE"
SAVE_PATH="$(pwd)/$OUTPUT_FILE"

echo "Opening Chrome and printing to PDF..."

# AppleScript to automate the entire print process
osascript << EOF
tell application "Google Chrome"
    activate
    open location "$FULL_PATH"
    delay 5
    
    -- Wait for page to load
    repeat 15 times
        delay 1
        try
            if (loading of active tab of front window) is false then exit repeat
        end try
    end repeat
end tell

-- Use UI scripting to automate print dialog
tell application "System Events"
    tell process "Google Chrome"
        -- Open print dialog
        keystroke "p" using command down
        delay 3
        
        -- Look for the destination dropdown and click it
        try
            click pop up button 1 of group 1 of group 1 of sheet 1 of front window
            delay 1
            
            -- Select "Save as PDF"
            click menu item "Save as PDF" of menu 1 of pop up button 1 of group 1 of group 1 of sheet 1 of front window
            delay 1
            
            -- Click the Save button
            click button "Save" of group 1 of group 1 of sheet 1 of front window
            delay 2
            
            -- In save dialog, clear filename field and type our path
            keystroke "a" using command down
            keystroke "$SAVE_PATH"
            delay 1
            
            -- Press Enter to save
            keystroke return
            delay 3
            
        on error errMsg
            display dialog "Error during print automation: " & errMsg
        end try
    end tell
end tell

-- Close the Chrome tab
tell application "Google Chrome"
    tell active tab of front window to close
end tell
EOF

# Check if PDF was created
if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
    echo "✅ PDF created successfully: $OUTPUT_FILE"
    ls -lh "$OUTPUT_FILE"
else
    echo "❌ PDF creation failed. You may need to enable accessibility permissions for Terminal in System Preferences > Security & Privacy > Privacy > Accessibility"
    exit 1
fi