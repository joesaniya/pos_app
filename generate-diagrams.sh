#!/bin/bash

# POS App - Mermaid Diagram Generator for Linux/macOS
# Usage: ./generate-diagrams.sh

set -e

echo ""
echo "================================"
echo "POS App Flowchart Generator"
echo "================================"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "ERROR: Node.js is not installed"
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

# Check if mermaid-cli is installed
if ! command -v mmdc &> /dev/null; then
    echo "WARNING: mermaid-cli not found in PATH"
    echo "Installing mermaid-cli globally..."
    npm install -g @mermaid-js/mermaid-cli
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to install mermaid-cli"
        exit 1
    fi
fi

echo "Running diagram generator..."
echo ""

# Run the Node.js script
node generate-diagrams.js

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Diagrams generated successfully!"
    echo ""
    echo "Generator completed:"
    echo "  📂 Output: ./diagrams/"
    echo "  📄 View: diagrams/index.html"
    echo ""
    
    # Try to open in browser
    if command -v xdg-open &> /dev/null; then
        xdg-open diagrams/index.html
    elif command -v open &> /dev/null; then
        open diagrams/index.html
    fi
else
    echo ""
    echo "ERROR: Diagram generation failed!"
    exit 1
fi
