# Supabase Migracija - Brzi Start

## ✅ Šta je urađeno

1. ✅ Kreirana Supabase upload skripta (`scripts/upload_json_to_supabase.py`)
2. ✅ Kreirana SQL shema (`scripts/supabase_schema.sql`)
3. ✅ Kreiran `SupabaseService.swift` (zamenjuje `FirebaseService`)
4. ✅ Ažurirani ViewModels da koriste Supabase
5. ✅ Kreiran `SupabaseConfig.swift` za credentials

## 🚀 Sledeći koraci

### 1. Kreiraj Supabase projekat
- Idite na https://supabase.com
- Kliknite "New Project"
- Sačekajte da se kreira (~2 minuta)

### 2. Pokreni SQL shemu
- U Supabase Dashboard: **SQL Editor** > **New Query**
- Kopiraj sadržaj iz `scripts/supabase_schema.sql`
- Klikni **Run**

### 3. Dobij API credentials
- **Project Settings** > **API**
- Kopiraj **Project URL** i **anon public** key

### 4. Konfiguriši Swift aplikaciju
- Otvori `TraningPlan2026/Config/SupabaseConfig.swift`
- Zameni `YOUR_SUPABASE_URL` i `YOUR_SUPABASE_ANON_KEY`

### 5. Instaliraj Supabase Swift SDK
- U Xcode: **File** > **Add Packages...**
- URL: `https://github.com/supabase/supabase-swift`
- Izaberi: `Supabase` i `Realtime`

### 6. Upload podataka
```bash
cd scripts
pip install supabase
python3 upload_json_to_supabase.py program-102234.json <URL> <KEY>
python3 upload_json_to_supabase.py meal-plan-102234.json <URL> <KEY>
```

### 7. Ukloni Firebase (opciono)
- Ukloni Firebase paket iz Xcode
- U `TraningPlan2026App.swift`, ukloni Firebase inicijalizaciju

## 📊 Prednosti Supabase

- ✅ **Nema dnevne limite** - samo hardverski kapacitet
- ✅ **Brže upload** - batch operacije (500 redova odjednom)
- ✅ **Real-time sync** - kao Firebase
- ✅ **Besplatan tier** - 500MB baze, 2GB bandwidth
- ✅ **SQL pristup** - direktno query-ovanje u SQL Editor-u

## 📝 Napomene

- Real-time subscription možda neće raditi odmah - proveri RLS policies
- Ako imaš greške, proveri `MIGRATION_GUIDE.md` za troubleshooting
- Za AI servise koristi lokalni secret (ne commit): napravi `TraningPlan2026/Config/Secrets.xcconfig` po šablonu `TraningPlan2026/Config/Secrets.xcconfig.example` i postavi `OPENAI_API_KEY`.
- U Xcode (Scheme ili Build Settings) prosledi `OPENAI_API_KEY` iz lokalnog `Secrets.xcconfig` ili kao env var u run scheme.
- Ako `OPENAI_API_KEY` nije podešen ili API nije dostupan, app automatski koristi lokalni fallback estimator.
