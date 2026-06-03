#!/bin/bash

# Skripta za automatsku konverziju PDF-ova u JSON i učitavanje u Firebase
# Upotreba: ./process_pdfs.sh <service_account.json>

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Aktiviraj virtual environment ako postoji
if [ -d "$SCRIPT_DIR/venv" ]; then
    source "$SCRIPT_DIR/venv/bin/activate"
    echo "✓ Virtual environment aktiviran"
fi

# Provera argumenta
SERVICE_ACCOUNT=""

if [ $# -lt 1 ]; then
    # Pokušaj da nađeš service account fajl - prvo u scripts folderu, pa u root
    if [ -f "$SCRIPT_DIR/service-account.json" ]; then
        SERVICE_ACCOUNT="$SCRIPT_DIR/service-account.json"
        echo "✓ Pronađen service account: $SERVICE_ACCOUNT"
    elif [ -f "$PROJECT_ROOT/service-account.json" ]; then
        SERVICE_ACCOUNT="$PROJECT_ROOT/service-account.json"
        echo "✓ Pronađen service account: $SERVICE_ACCOUNT"
    else
        echo "Upotreba: $0 [service_account.json]"
        echo ""
        echo "Service account fajl nije pronađen. Možete:"
        echo "  1. Proslediti putanju kao argument: $0 /path/to/service-account.json"
        echo "  2. Sačuvati fajl kao 'service-account.json' u root direktorijumu projekta"
        echo "  3. Sačuvati fajl kao 'service-account.json' u scripts direktorijumu"
        echo ""
        echo "Kako dobiti service account fajl:"
        echo "  1. Idite u Firebase Console: https://console.firebase.google.com/"
        echo "  2. Izaberite vaš projekat"
        echo "  3. Project Settings > Service Accounts"
        echo "  4. Kliknite 'Generate New Private Key'"
        echo "  5. Sačuvajte JSON fajl"
        exit 1
    fi
else
    SERVICE_ACCOUNT="$1"
    
    # Ako je relativna putanja, pretvori u apsolutnu
    if [[ ! "$SERVICE_ACCOUNT" = /* ]]; then
        # Relativna putanja - pokušaj iz trenutnog direktorijuma
        if [ -f "$(pwd)/$SERVICE_ACCOUNT" ]; then
            SERVICE_ACCOUNT="$(cd "$(dirname "$(pwd)/$SERVICE_ACCOUNT")" && pwd)/$(basename "$SERVICE_ACCOUNT")"
        # Pokušaj iz scripts direktorijuma
        elif [ -f "$SCRIPT_DIR/$SERVICE_ACCOUNT" ]; then
            SERVICE_ACCOUNT="$SCRIPT_DIR/$SERVICE_ACCOUNT"
        # Pokušaj iz project root
        elif [ -f "$PROJECT_ROOT/$SERVICE_ACCOUNT" ]; then
            SERVICE_ACCOUNT="$PROJECT_ROOT/$SERVICE_ACCOUNT"
        fi
    fi
fi

if [ ! -f "$SERVICE_ACCOUNT" ]; then
    echo "❌ Greška: Service account fajl ne postoji: $SERVICE_ACCOUNT"
    echo ""
    echo "Proverite da li je putanja tačna. Možete koristiti apsolutnu ili relativnu putanju."
    exit 1
fi

echo "✓ Koristim service account: $SERVICE_ACCOUNT"
echo ""

# PDF fajlovi - prvo proveri u scripts folderu, pa u root
if [ -f "$SCRIPT_DIR/program-102234.pdf" ]; then
    WORKOUT_PDF="$SCRIPT_DIR/program-102234.pdf"
elif [ -f "$PROJECT_ROOT/program-102234.pdf" ]; then
    WORKOUT_PDF="$PROJECT_ROOT/program-102234.pdf"
else
    WORKOUT_PDF=""
fi

if [ -f "$SCRIPT_DIR/meal-plan-102234.pdf" ]; then
    MEAL_PDF="$SCRIPT_DIR/meal-plan-102234.pdf"
elif [ -f "$PROJECT_ROOT/meal-plan-102234.pdf" ]; then
    MEAL_PDF="$PROJECT_ROOT/meal-plan-102234.pdf"
else
    MEAL_PDF=""
fi

# JSON fajlovi - čuvaju se u scripts folderu
WORKOUT_JSON="$SCRIPT_DIR/program-102234.json"
MEAL_JSON="$SCRIPT_DIR/meal-plan-102234.json"

echo "=== PDF to JSON Converter ==="
echo ""

# Konvertuj workout plan
if [ -f "$WORKOUT_PDF" ]; then
    echo "Konvertovanje workout plana..."
    python3 "$SCRIPT_DIR/pdf_to_json.py" "$WORKOUT_PDF" "$WORKOUT_JSON"
    echo ""
else
    echo "⚠️  Upozorenje: $WORKOUT_PDF ne postoji"
fi

# Konvertuj meal plan
if [ -f "$MEAL_PDF" ]; then
    echo "Konvertovanje meal plana..."
    python3 "$SCRIPT_DIR/pdf_to_json.py" "$MEAL_PDF" "$MEAL_JSON"
    echo ""
else
    echo "⚠️  Upozorenje: $MEAL_PDF ne postoji"
fi

echo "=== Upload to Firebase ==="
echo ""

# Učitaj workout plan
if [ -f "$WORKOUT_JSON" ]; then
    echo "Učitavanje workout plana u Firebase..."
    python3 "$SCRIPT_DIR/upload_json_to_firebase.py" "$WORKOUT_JSON" --service-account "$SERVICE_ACCOUNT"
    echo ""
else
    echo "⚠️  Upozorenje: $WORKOUT_JSON ne postoji"
fi

# Učitaj meal plan
if [ -f "$MEAL_JSON" ]; then
    echo "Učitavanje meal plana u Firebase..."
    python3 "$SCRIPT_DIR/upload_json_to_firebase.py" "$MEAL_JSON" --service-account "$SERVICE_ACCOUNT"
    echo ""
else
    echo "⚠️  Upozorenje: $MEAL_JSON ne postoji"
fi

echo "✓ Završeno!"
echo ""
echo "Proverite Firebase Console da li su podaci uspešno učitani."
