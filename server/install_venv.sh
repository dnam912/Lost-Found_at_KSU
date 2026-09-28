#!/usr/bin/env bash

set -e

cd "$(dirname "$0")"

echo "========================================"
echo "Python Virtual Environment Setup"
echo "========================================"
echo

# Python check
if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERROR] Python 3 is not installed or not in PATH."
    exit 1
fi

# Require Python 3.11 or higher
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'; then
    echo "[ERROR] Python 3.11 or higher is required."
    echo "Current Python version:"
    python3 --version
    exit 1
fi

echo "Python version check passed:"
python3 --version
echo

# Create venv if it does not exist
if [ ! -x ".venv/bin/python" ]; then
    echo "[1/4] Creating .venv..."
    python3 -m venv .venv
else
    echo "[1/4] .venv already exists. Skipping creation."
fi

echo
echo "[2/4] Upgrading pip..."

".venv/bin/python" -m pip install --upgrade pip

echo
echo "[3/4] Installing requirements.txt..."

if [ ! -f "requirements.txt" ]; then
    echo "[ERROR] requirements.txt not found."
    exit 1
fi

".venv/bin/python" -m pip install -r requirements.txt

echo
echo "[4/4] Installing spaCy English model..."

".venv/bin/python" -m spacy download en_core_web_sm

echo
echo "========================================"
echo "Environment setup complete!"
echo "========================================"
echo
echo "Virtual environment:"
echo "$(pwd)/.venv"
