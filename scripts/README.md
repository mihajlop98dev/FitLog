# PDF to Firebase Skripte

Ove skripte konvertuju PDF fajlove u JSON format i učitavaju ih u Firebase Firestore.

## Brza Instalacija (Preporučeno)

Pokrenite setup skriptu koja automatski kreira virtual environment i instalira sve potrebno:

```bash
cd scripts
./setup.sh
```

Ovo će:
1. Kreirati Python virtual environment
2. Instalirati sve potrebne pakete (PyPDF2, firebase-admin)
3. Pripremiti sve za korišćenje

Nakon setup-a, aktivirajte virtual environment pre korišćenja skripti:
```bash
cd scripts
source venv/bin/activate
```

## Ručna Instalacija

### macOS

1. Proverite da li imate Python 3 instaliran:
```bash
python3 --version
```

2. Ako nemate Python 3, instalirajte ga:
```bash
# Opcija 1: Preko Homebrew (preporučeno)
brew install python3

# Opcija 2: Preuzmite sa python.org
# https://www.python.org/downloads/
```

3. Instalirajte potrebne Python pakete:

**Opcija A: Koristite virtual environment (preporučeno)**
```bash
# Kreiraj virtual environment u scripts direktorijumu
cd scripts
python3 -m venv venv

# Aktiviraj virtual environment
source venv/bin/activate

# Instaliraj pakete
pip install PyPDF2 firebase-admin

# Kada završite, deaktiviraj sa:
# deactivate
```

**Opcija B: Instaliraj za korisnika (--user flag)**
```bash
pip3 install --user PyPDF2 firebase-admin
```

**Opcija C: Koristite --break-system-packages (ne preporučeno)**
```bash
pip3 install --break-system-packages PyPDF2 firebase-admin
```

⚠️ **Napomena**: Ako koristite virtual environment (Opcija A), morate aktivirati ga pre pokretanja skripti:
```bash
cd scripts
source venv/bin/activate
python3 pdf_to_json.py ...
```

### Windows / Linux

```bash
# Proverite verziju
python --version
# ili
python3 --version

# Instalirajte pakete
pip install PyPDF2 firebase-admin
# ili
pip3 install PyPDF2 firebase-admin
```

## Korak 1: Konverzija PDF u JSON

Koristite `pdf_to_json.py` skriptu da konvertujete PDF fajlove u JSON:

```bash
# Za workout plan
python3 scripts/pdf_to_json.py program-102234.pdf program-102234.json

# Za meal plan
python3 scripts/pdf_to_json.py meal-plan-102234.pdf meal-plan-102234.json
```

Skripta će automatski detektovati tip plana na osnovu imena fajla.

## Korak 2: Preuzimanje Service Account Key

1. Idite u [Firebase Console](https://console.firebase.google.com/)
2. Izaberite vaš projekat
3. Idite na **Project Settings** > **Service Accounts**
4. Kliknite **Generate New Private Key**
5. Sačuvajte JSON fajl kao `service-account.json` u **root direktorijumu projekta** (gde su PDF fajlovi)

⚠️ **VAŽNO**: 
- Ne commit-ujte service account fajl u git! Već je dodat u `.gitignore`.
- Sačuvajte fajl u root direktorijumu projekta (isti nivo kao `program-102234.pdf`)

**Lokacija fajlova (možete staviti u scripts folder ili root):**
```
TraningPlan2026/
├── service-account.json  ← Opcija 1: Root direktorijum
├── program-102234.pdf
├── meal-plan-102234.pdf
└── scripts/
    ├── service-account.json  ← Opcija 2: Scripts folder (preporučeno)
    ├── program-102234.pdf
    └── meal-plan-102234.pdf
```

Skripta automatski traži fajlove u oba mesta (prvo u scripts folderu, pa u root).

## Korak 3: Učitavanje JSON u Firebase

Koristite `upload_json_to_firebase.py` skriptu da učitete JSON fajlove u Firebase:

```bash
# Za workout plan
python3 scripts/upload_json_to_firebase.py program-102234.json --service-account service-account.json

# Za meal plan
python3 scripts/upload_json_to_firebase.py meal-plan-102234.json --service-account service-account.json
```

## Kompletna Komanda (jednom linijom)

Možete kombinovati oba koraka:

```bash
# Konvertuj i učitaj workout plan
python3 scripts/pdf_to_json.py program-102234.pdf program-102234.json && \
python3 scripts/upload_json_to_firebase.py program-102234.json --service-account service-account.json

# Konvertuj i učitaj meal plan
python3 scripts/pdf_to_json.py meal-plan-102234.pdf meal-plan-102234.json && \
python3 scripts/upload_json_to_firebase.py meal-plan-102234.json --service-account service-account.json
```

## Automatska Skripta (Preporučeno)

Koristite `process_pdfs.sh` skriptu koja automatski pokreće oba koraka:

```bash
# Pokreni skriptu (automatski konvertuje oba PDF-a i učitava ih u Firebase)
# Ako je service-account.json u root direktorijumu, možete pokrenuti bez argumenta:
./scripts/process_pdfs.sh

# ILI prosledite putanju:
./scripts/process_pdfs.sh service-account.json
./scripts/process_pdfs.sh /full/path/to/service-account.json
```

Skripta će:
1. Konvertovati `program-102234.pdf` u JSON
2. Konvertovati `meal-plan-102234.pdf` u JSON
3. Učitati oba JSON fajla u Firebase

## Provera

Nakon učitavanja, proverite u Firebase Console da li su podaci uspešno učitani:
- **Firestore Database** > **workoutPlans** kolekcija
- **Firestore Database** > **mealPlans** kolekcija

## Troubleshooting

### Greška: "PyPDF2 not found"
```bash
pip3 install PyPDF2
```

### Greška: "firebase-admin not found"
```bash
pip3 install firebase-admin
```

### Greška: "python3: command not found"
Na macOS, Python 3 se obično instalira preko Homebrew:
```bash
# Instaliraj Homebrew ako ga nemaš
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Instaliraj Python 3
brew install python3
```

Ili preuzmi Python 3 sa [python.org](https://www.python.org/downloads/)

### Greška: "Service account not found"
- Proverite da li je putanja do service account fajla tačna
- Proverite da li fajl postoji i da li imate dozvolu za čitanje

### Greška: "Permission denied"
- Proverite da li service account ima dozvole za pisanje u Firestore
- U Firebase Console, idite na **Firestore Database** > **Rules** i omogućite pisanje (za development)
