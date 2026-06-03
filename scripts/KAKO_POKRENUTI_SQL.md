# Kako pokrenuti supabase_schema.sql

## Korak po korak:

### 1. Otvori Supabase Dashboard
- Idite na https://supabase.com
- Prijavite se
- Kliknite na svoj projekat (ili kreirajte novi ako ga nema)

### 2. Otvori SQL Editor
- U levom meniju, kliknite na **SQL Editor** (ikonica sa `</>` ili "SQL Editor")
- Ili direktno: https://supabase.com/dashboard/project/[YOUR_PROJECT_ID]/sql/new

### 3. Kreiraj novi query
- Kliknite na dugme **New Query** (gore desno)
- Ili koristite `Cmd+N` / `Ctrl+N`

### 4. Kopiraj SQL skriptu
- Otvori fajl `scripts/supabase_schema.sql` u editoru
- Selektuj SVE (Cmd+A / Ctrl+A)
- Kopiraj (Cmd+C / Ctrl+C)

### 5. Nalepi u SQL Editor
- Vrati se u Supabase SQL Editor
- Nalepi SQL kod (Cmd+V / Ctrl+V)

### 6. Pokreni SQL
- Klikni na dugme **Run** (ili pritisni `Cmd+Enter` / `Ctrl+Enter`)
- Sačekaj da se izvrši (obično traje 1-2 sekunde)

### 7. Proveri rezultat
- Trebalo bi da vidiš poruku "Success. No rows returned"
- Proveri da li su tabele kreirane:
  - U levom meniju, klikni na **Table Editor**
  - Trebalo bi da vidiš tabele: `workout_plans`, `workouts`, `exercises`, `meal_plans`, `meals`, `foods`, itd.

## Ako imaš grešku:

### Greška: "relation already exists"
- Tabele već postoje - to je OK, možeš da ih obrišeš i pokreneš ponovo ili da ignorišeš

### Greška: "permission denied"
- Proveri da li si prijavljen u Supabase
- Proveri da li imaš pristup projektu

### Greška: "syntax error"
- Proveri da li si kopirao ceo fajl
- Proveri da li nema dodatnih karaktera

## Alternativni način (ako SQL Editor ne radi):

1. Otvori **Table Editor**
2. Klikni **New Table** za svaku tabelu
3. Ručno kreiraj kolone prema shemi iz `supabase_schema.sql`

## Screenshot lokacije:

```
Supabase Dashboard
├── Project Settings (⚙️)
├── Table Editor (📊) ← Ovde vidiš tabele posle kreiranja
├── SQL Editor (</>) ← OVDE pokrećeš SQL skriptu
├── Database
└── ...
```
