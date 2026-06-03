# Test Supabase Integracije

## ✅ Šta je urađeno

1. ✅ Uklonjena Firebase inicijalizacija iz `TraningPlan2026App.swift`
2. ✅ SupabaseService koristi `SupabaseConfig.shared.supabase`
3. ✅ ViewModels koriste SupabaseService
4. ✅ SupabaseConfig je konfigurisan sa credentials-ima

## 🧪 Testiranje

### 1. Build aplikacije
- Otvori Xcode
- Pritisni `Cmd+B` da build-uješ aplikaciju
- Proveri da li ima grešaka

### 2. Test učitavanja planova
- Pokreni aplikaciju (`Cmd+R`)
- Proveri da li se učitavaju workout planovi
- Proveri da li se učitavaju meal planovi

### 3. Test dodavanja novih podataka
- Dodaj novi workout
- Dodaj novi meal
- Proveri da li se čuvaju u Supabase

### 4. Proveri Supabase Dashboard
- Idite u Supabase Dashboard > Table Editor
- Proveri da li se novi podaci pojavljuju u:
  - `user_workouts`
  - `user_meals`

## 🔍 Ako ima grešaka

### Greška: "Supabase credentials nisu konfigurisani"
- Proveri `SupabaseConfig.swift` - da li su URL i key ispravni

### Greška: "Table does not exist"
- Proveri da li si pokrenuo `supabase_schema.sql` u SQL Editor-u

### Greška: "Permission denied"
- Proveri Row Level Security (RLS) policies u Supabase
- U SQL Editor-u, pokreni:
```sql
-- Dozvoli sve operacije (za development)
ALTER TABLE user_workouts DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_meals DISABLE ROW LEVEL SECURITY;
```

### Greška: "Cannot find 'SupabaseClient' in scope"
- Proveri da li si instalirao Supabase Swift SDK
- File > Add Packages... > `https://github.com/supabase/supabase-swift`
- Izaberi `Supabase` i `Realtime`

## 📊 Provera podataka u Supabase

### Workout Plans
```sql
SELECT * FROM workout_plans;
SELECT COUNT(*) FROM workouts;
SELECT COUNT(*) FROM exercises;
```

### Meal Plans
```sql
SELECT * FROM meal_plans;
SELECT COUNT(*) FROM meals;
SELECT COUNT(*) FROM foods;
```

### User Data
```sql
SELECT * FROM user_workouts ORDER BY date DESC;
SELECT * FROM user_meals ORDER BY date DESC;
```

## ✅ Uspešno ako:

- ✅ Aplikacija se build-uje bez grešaka
- ✅ Planovi se učitavaju pri pokretanju
- ✅ Možeš da dodaš novi workout/meal
- ✅ Podaci se čuvaju u Supabase
- ✅ Real-time sync radi (opciono)
