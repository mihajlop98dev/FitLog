# Migracija sa Firebase na Supabase

## Koraci za migraciju

### 1. Kreiranje Supabase Projekta

1. Idite na https://supabase.com i kreirajte novi projekat
2. Sačekajte da se projekat kreira (~2 minuta)
3. Idite u **SQL Editor** i pokrenite `supabase_schema.sql`
4. Proverite da li su tabele kreirane u **Table Editor**

### 2. Dobijanje API Credentials

1. **Project Settings** > **API**
2. Kopirajte:
   - **Project URL** (npr. `https://xxxxx.supabase.co`)
   - **anon public** key

### 3. Konfiguracija Swift Aplikacije

1. Otvori `TraningPlan2026/Config/SupabaseConfig.swift`
2. Zameni `YOUR_SUPABASE_URL` i `YOUR_SUPABASE_ANON_KEY` sa svojim credentials

```swift
struct SupabaseConfig {
    static let url = "https://xxxxx.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### 4. Instalacija Swift SDK

1. U Xcode: **File** > **Add Packages...**
2. Unesi: `https://github.com/supabase/supabase-swift`
3. Izaberi `Supabase` i `Realtime` pakete
4. Klikni **Add Package**

### 5. Uklanjanje Firebase

1. Ukloni Firebase paket iz Xcode projekta
2. Obriši `GoogleService-Info.plist` (opciono)
3. U `TraningPlan2026App.swift`, ukloni Firebase inicijalizaciju:

```swift
// Ukloni ovo:
import FirebaseCore
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(...) -> Bool {
    FirebaseApp.configure()  // Ukloni ovu liniju
    return true
  }
}
```

Ili jednostavno ukloni `AppDelegate` ako nije potreban:

```swift
@main
struct TraningPlan2026App: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
```

### 6. Upload Podataka u Supabase

```bash
cd scripts
source venv/bin/activate  # ili kreiraj novi venv
pip install supabase

# Upload workout plan
python3 upload_json_to_supabase.py program-102234.json <SUPABASE_URL> <SUPABASE_KEY>

# Upload meal plan
python3 upload_json_to_supabase.py meal-plan-102234.json <SUPABASE_URL> <SUPABASE_KEY>
```

### 7. Testiranje

1. Pokreni aplikaciju u Xcode
2. Proveri da li se planovi učitavaju
3. Proveri da li možeš da dodaješ nove treninge/obroke

## Prednosti Supabase

✅ **Nema dnevne limite** - samo hardverski kapacitet  
✅ **Brže upload** - batch operacije (500 redova odjednom)  
✅ **Real-time sync** - kao Firebase  
✅ **Besplatan tier** - 500MB baze, 2GB bandwidth  
✅ **SQL pristup** - možeš direktno da query-uješ u SQL Editor-u  

## Troubleshooting

### Greška: "Supabase credentials nisu konfigurisani"
- Proveri da li si ažurirao `SupabaseConfig.swift` sa svojim credentials

### Greška: "Table does not exist"
- Proveri da li si pokrenuo `supabase_schema.sql` u SQL Editor-u

### Greška: "Permission denied"
- Proveri Row Level Security (RLS) policies u Supabase
- U SQL Editor-u, pokreni:
```sql
-- Dozvoli sve operacije (za development)
ALTER TABLE workout_plans DISABLE ROW LEVEL SECURITY;
-- ... za sve tabele
```

### Real-time ne radi
- Proveri da li je Realtime omogućen u Supabase Dashboard
- Proveri da li su RLS policies ispravno podešene
