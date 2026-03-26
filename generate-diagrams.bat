@echo off
REM POS App - Mermaid Diagram Generator for Windows
REM Usage: generate-diagrams.bat

echo.
echo ================================
echo POS App Flowchart Generator
echo ================================
echo.

REM Check if Node.js is installed
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

REM Check if mermaid-cli is installed
where mmdc >nul 2>nul
if %errorlevel% neq 0 (
    echo WARNING: mermaid-cli not found in PATH
    echo Installing mermaid-cli globally...
    call npm install -g @mermaid-js/mermaid-cli
    if %errorlevel% neq 0 (
        echo ERROR: Failed to install mermaid-cli
        pause
        exit /b 1
    )
)

echo Running diagram generator...
echo.

REM Run the Node.js script
node generate-diagrams.js

if %errorlevel% equ 0 (
    echo.
    echo ✓ Diagrams generated successfully!
    echo.
    echo Opening diagram viewer...
    start diagrams\index.html
) else (
    echo.
    echo ERROR: Diagram generation failed!
    pause
    exit /b 1
)

pause
