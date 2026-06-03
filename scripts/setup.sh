#!/bin/bash

# Setup skripta za kreiranje virtual environment-a i instalaciju paketa

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "=== Python Virtual Environment Setup ==="
echo ""

# Proveri da li postoji Python 3
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 nije instaliran!"
    echo "Instalirajte Python 3:"
    echo "  brew install python3"
    echo "  ili preuzmite sa https://www.python.org/downloads/"
    exit 1
fi

echo "✓ Python 3 pronađen: $(python3 --version)"
echo ""

# Kreiraj virtual environment ako ne postoji
if [ ! -d "venv" ]; then
    echo "Kreiranje virtual environment-a..."
    python3 -m venv venv
    echo "✓ Virtual environment kreiran"
else
    echo "✓ Virtual environment već postoji"
fi

echo ""
echo "Aktiviranje virtual environment-a..."
source venv/bin/activate

echo ""
echo "Instaliranje paketa..."
pip install --upgrade pip
pip install PyPDF2 firebase-admin

echo ""
echo "✓ Setup završen!"
echo ""
echo "Sledeći put, aktivirajte virtual environment sa:"
echo "  cd scripts"
echo "  source venv/bin/activate"
echo ""
echo "Zatim možete koristiti skripte:"
echo "  python3 pdf_to_json.py ..."
echo "  python3 upload_json_to_firebase.py ..."
