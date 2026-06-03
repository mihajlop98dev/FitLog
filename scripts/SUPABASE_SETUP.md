# Supabase Setup Guide

## 1. Kreiranje Supabase Projekta

1. Idite na https://supabase.com
2. Kliknite "Start your project"
3. Prijavite se (GitHub account)
4. Kliknite "New Project"
5. Unesite:
   - **Name**: TraningPlan2026
   - **Database Password**: (zapamtite ovo!)
   - **Region**: Izaberite najbližu
6. Kliknite "Create new project"
7. Sačekajte da se projekat kreira (~2 minuta)

## 2. Kreiranje Database Schema

1. U Supabase Dashboard-u, idite na **SQL Editor**
2. Kliknite **New Query**
3. Kopirajte i nalepite sadržaj iz `supabase_schema.sql`
4. Kliknite **Run** (ili Cmd+Enter)
5. Proverite da li su tabele kreirane u **Table Editor**

## 3. Dobijanje API Credentials

1. Idite na **Project Settings** (⚙️ ikona)
2. Kliknite **API** u levom meniju
3. Kopirajte:
   - **Project URL** (npr. `https://xxxxx.supabase.co`)
   - **anon public** key (ovo je API key)

## 4. Instalacija Python SDK

```bash
cd scripts
source venv/bin/activate  # ili kreiraj novi venv
pip install supabase
```

## 5. Upload Podataka

```bash
# Upload workout plan
python3 upload_json_to_supabase.py program-102234.json https://fduykeeoygffgxkvwmyl.supabase.co sb_publishable_najmruv4yCXU1Qp-tiyE4A_WYPMWxo5

# Upload meal plan
python3 upload_json_to_supabase.py meal-plan-102234.json https://fduykeeoygffgxkvwmyl.supabase.co sb_publishable_najmruv4yCXU1Qp-tiyE4A_WYPMWxo5
```

## 6. Instalacija Swift SDK

U Xcode projektu, dodaj Supabase Swift SDK:

1. File > Add Packages...
2. Unesite: `https://github.com/supabase/supabase-swift`
3. Kliknite "Add Package"
4. Izaberite `Supabase` i `Realtime`

## 7. Konfiguracija u Swift

Kreiraj `SupabaseConfig.swift` sa:

```swift
import Foundation
import Supabase

class SupabaseConfig {
    static let shared = SupabaseConfig()
    
    let supabase: SupabaseClient
    
    private init() {
        let url = URL(string: "YOUR_SUPABASE_URL")!
        let key = "YOUR_SUPABASE_ANON_KEY"
        supabase = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
}
```

## Prednosti Supabase

✅ **Nema dnevne limite** - samo hardverski kapacitet  
✅ **Brže upload** - batch operacije (500 redova odjednom)  
✅ **Real-time sync** - kao Firebase  
✅ **Besplatan tier** - 500MB baze, 2GB bandwidth  
✅ **SQL pristup** - možeš direktno da query-uješ u SQL Editor-u  

## Migracija iz Firebase

1. Uploaduj podatke u Supabase (koristi upload skriptu)
2. Zameni Firebase SDK sa Supabase SDK u Swift
3. Ažuriraj servise da koriste Supabase
4. Testiraj aplikaciju
5. Obriši Firebase podatke (opciono)
