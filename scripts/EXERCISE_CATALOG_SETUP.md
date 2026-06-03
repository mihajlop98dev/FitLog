# Exercise Catalog Setup

## Opis

Katalog vežbi (`exercise_catalog`) je tabela koja sadrži sve jedinstvene vežbe iz workout plana. Ovo omogućava brže učitavanje vežbi u aplikaciji i automatsko dodavanje novih vežbi.

Vežbe su analizirane pomoću AI da se identifikuju duplikati i kategorizuju po delovima tela.

## 1. Kreiranje Tabele

Tabela je već kreirana u `supabase_schema.sql`. Ako još nisi pokrenuo SQL skriptu, pokreni je u Supabase SQL Editor-u.

## 2. AI Analiza i Ekstrakcija Vežbi

**Preporučeno:** Koristi AI skriptu koja bolje identifikuje duplikate i kategorizuje vežbe:

```bash
cd scripts
source venv/bin/activate  # ili kreiraj novi venv
pip install openai supabase  # ako još nije instalirano

# AI analiza vežbi (preporučeno)
python3 ai_analyze_exercises.py \
  program-102234.json \
  https://fduykeeoygffgxkvwmyl.supabase.co \
  sb_publishable_najmruv4yCXU1Qp-tiyE4A_WYPMWxo5 \
  sk-tvoj-openai-api-key \
  --clear
```

**Alternativa:** Ako nemaš OpenAI API key, možeš koristiti osnovnu skriptu:

```bash
# Osnovna ekstrakcija (bez AI)
python3 extract_exercises_to_catalog.py \
  program-102234.json \
  https://fduykeeoygffgxkvwmyl.supabase.co \
  sb_publishable_najmruv4yCXU1Qp-tiyE4A_WYPMWxo5 \
  --clear
```

**Kako dobiti OpenAI API key:**
1. Idite na https://platform.openai.com/api-keys
2. Kliknite "Create new secret key"
3. Kopirajte key (počinje sa `sk-`)

## 3. Kako Radi

### U Aplikaciji

1. **Učitavanje vežbi**: Kada se aplikacija pokrene, automatski se učitavaju sve vežbe iz `exercise_catalog` tabele
2. **Izbor vežbe**: Kada korisnik dodaje novi trening i klikne "Dodaj Vežbu", može da izabere vežbu iz kataloga
3. **Dodavanje nove vežbe**: Ako korisnik unese vežbu koja nije u katalogu, automatski se dodaje u katalog

### Struktura Tabele

```sql
CREATE TABLE exercise_catalog (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 4. Prednosti

✅ **Brže učitavanje** - samo jedna tabela sa imenima vežbi (ne mora da učitava sve vežbe iz svih treninga)  
✅ **Jednostavnije** - samo ime vežbe, bez dodatnih podataka  
✅ **Automatsko dodavanje** - nove vežbe se automatski dodaju u katalog  
✅ **Bez duplikata** - UNIQUE constraint osigurava da nema duplikata  

## 5. Provera

Možeš proveriti da li su vežbe uspešno upisane u Supabase SQL Editor-u:

```sql
SELECT COUNT(*) FROM exercise_catalog;
SELECT * FROM exercise_catalog ORDER BY name LIMIT 20;
```
