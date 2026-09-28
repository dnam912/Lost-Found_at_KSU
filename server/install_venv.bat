@echo off
title Python Environment Setup

cd /d "%~dp0"

echo ========================================
echo Python Virtual Environment Setup
echo ========================================
echo.

echo ========================================
echo Python Virtual Environment Setup
echo ========================================
echo.

REM Python check
python --version >nul 2>&1

if errorlevel 1 (
    echo [ERROR] Python is not installed or not in PATH.
    pause
    exit /b 1
)

REM Require Python 3.11 or higher
python -c "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)"

if errorlevel 1 (
    echo [ERROR] Python 3.11 or higher is required.
    echo Current Python version:
    python --version
    pause
    exit /b 1
)

echo Python version check passed:
python --version
echo.


REM Create venv if it does not exist
if not exist ".venv\Scripts\python.exe" (
    echo [1/4] Creating .venv...
    python -m venv .venv

    if errorlevel 1 (
        echo [ERROR] Failed to create virtual environment.
        pause
        exit /b 1
    )
) else (
    echo [1/4] .venv already exists. Skipping creation.
)

echo.
echo [2/4] Upgrading pip...

".venv\Scripts\python.exe" -m pip install --upgrade pip

if errorlevel 1 (
    echo [ERROR] Failed to upgrade pip.
    pause
    exit /b 1
)

echo.
echo [3/4] Installing requirements.txt...

if not exist "requirements.txt" (
    echo [ERROR] requirements.txt not found.
    pause
    exit /b 1
)

".venv\Scripts\python.exe" -m pip install -r requirements.txt

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to install requirements.
    pause
    exit /b 1
)

echo.
echo [4/4] Installing spaCy English model...

".venv\Scripts\python.exe" -m spacy download en_core_web_sm

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to install spaCy model.
    pause
    exit /b 1
)

echo.
echo ========================================
echo Environment setup complete!
echo ========================================
echo.
echo Virtual environment:
echo %CD%\.venv
echo.
pause