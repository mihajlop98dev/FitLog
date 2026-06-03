# FitLog - Onboarding, Profile & Feature Tiers Design

## Overview

Complete redesign of the first-time user experience and feature gating system. Covers:
- Onboarding flow (8 screens)
- Profile screen with stats and settings
- Feature tiers (Free, Ishrana add-on, Pro)
- User data isolation (RLS + user_id)
- AI plan generator (OpenAI + 175 template workouts)
- 7-day free trial with workout limit

---

## 9. Localization (Multi-language)

### Approach
- Use SwiftUI's built-in `LocalizedStringKey` + `.strings` / `.stringsdict` files
- English is the default development language
- Serbian (sr-RS) as secondary language
- User selects language in Profile → Settings
- Selection saved to `UserDefaults` with key `appLanguage`
- On change → trigger app restart or `UIApplication.shared.openSettings()` with instruction to restart

### Files to Create
- `Localizable.xcstrings` (or `en.lproj/Localizable.strings` + `sr.lproj/Localizable.strings`)
- All user-facing strings extracted from views

### Strings Coverage
- Onboarding (all 8 screens)
- Auth (login/register labels, errors)
- Dashboard (stat cards, progress text)
- Workouts list
- Meals sections (if has_nutrition)
- Profile screen
- Coach chat
- Error messages (from ViewModels)
- Notifications (daily check-in, weekly recap)

### Serbian Notes
- Uses Latinica script (not Cyrillic) for consistency with existing codebase
- AI-generated content (plan, chat) should match user's language preference
- `Locale(identifier: "sr_RS")` used for date formatting

---

## 1. Onboarding Flow

### Screens

1. **Welcome** — branding, "Započnimo" CTA, link za existing users
2. **Basic Info** — name, age, gender, weight, height
3. **Goal** — single-select: dobijanje mase, mršavljenje, održavanje, definicija
4. **Level + Equipment + Frequency** — level (3 tiers), days/week (2-6), equipment (multi-select: teretana/kućni/bodyweight)
5. **Injuries** — multi-select: leđa, kolena, ramena, vrat, zglobovi, none
6. **Nutrition** — binary: "Da, želim" / "Samo trening". If yes: meals/day (3-6), allergies (text)
7. **Motivation** — optional text field
8. **Review** — summary of all answers, "Kreiraj plan" button

### Behavior
- Ako korisnik izabere "Samo trening" na ekranu 6 → ishrana se nigde ne prikazuje u app (menu, dashboard, profil). Ali opcija za nadogradnju postoji u profilu.
- Nakon potvrde → poziva se AI plan generator → korisnik dobija plan i vidi se na dashboard-u.
- Profil se čuva u novoj tabeli `user_profiles` u Supabase.

---

## 2. Database Changes

### New Tables

```sql
-- Korisnički profili (onboarding podaci)
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id),
    name TEXT,
    age INT,
    gender TEXT,
    weight_kg DOUBLE PRECISION,
    height_cm DOUBLE PRECISION,
    goal TEXT NOT NULL, -- masa, mrsavljenje, odrzavanje, definicija
    level TEXT NOT NULL, -- pocetnik, srednji, napredan
    days_per_week INT NOT NULL,
    equipment TEXT[] NOT NULL, -- {teretana, kucni, bodyweight}
    injuries TEXT[], -- {ledja, kolena, ramena, vrat, zglobovi}
    has_nutrition BOOLEAN DEFAULT false,
    meals_per_day INT,
    allergies TEXT,
    motivation TEXT,
    trial_end_date TIMESTAMPTZ NOT NULL,
    feature_tier TEXT NOT NULL DEFAULT 'free', -- free, nutrition, pro
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### RLS Policies

- `user_profiles` — only own row (user_id = auth.uid())
- `workout_plans`, `meal_plans`, `exercise_catalog` — public (read only, source data)
- `workouts`, `exercises` — public (read only, source data)
- `user_workouts`, `user_meals`, `user_exercise_records`, `user_food_records`, `user_body_progress`, `user_training_plan_queue*`, `user_training_plan_progress` — auth.uid() based (insert/select/update/delete own)
- Storage bucket `body-progress-photos` — auth.uid() based

### Feature Gates

Check `user_profiles.feature_tier` to gate:
- `free`: workouts + basic tracking + 4-5 workouts total
- `nutrition`: workouts + meals + meal plans
- `pro`: all + AI coach chat

Trial: `user_profiles.trial_end_date` → after expiry, prevent new workout generation. Re-check on app launch and before AI plan generation.

---

## 3. Profile Screen

### Sadržaj
- **Header**: ime, email, member since
- **Stats**: total workouts, total meals (ako ima nutrition), streak days, days active
- **Settings**:
  - FaceID toggle (on/off, saved in UserDefaults)
  - Feature upgrades:
    - "Nadogradi na ishranu" (ako je free)
    - "Nadogradi na Pro" (ako nije pro)
  - Sign out button

### Streak Calculation
- Count consecutive days with at least one workout or meal entry
- Stored in user_profiles, recalculated on each new entry

---

## 4. AI Plan Generator

### Inputs
- Onboarding data (goal, level, days/week, equipment, injuries, nutrition flag)
- 175 template workouts from `workouts` + `exercises` tables (plan_id = "102234")

### Process
1. Filter 175 template workouts by equipment compatibility and injury exclusions
2. Group by muscle group / exercise category
3. Send to OpenAI (`gpt-4o-mini`) with:
   - System prompt: "You are a fitness coach creating personalized workout plans..."
   - User prompt: onboarding data + available template exercises
   - Response format: JSON array of `{name, day, exercises: [{name, sets, reps, weight}]}`
4. Save generated workouts to `user_workouts` + `user_exercise_records`
5. Return plan to user

### Output
- 4-5 workouts (depending on days/week)
- Each workout: 5-8 exercises with sets/reps
- Serbian language output

---

## 5. User Data Isolation

### Auth Integration
- Supabase Auth (email+password) already implemented
- Every `user_*` table needs `user_id` column added
- All queries filter by `auth.uid()`
- RLS policies updated from `true` to `auth.uid() = user_id`

### Migration
- Existing `user_*` rows that were public need `user_id` backfilled
- Script to assign all existing rows to the first user (mihajlop98dev@outlook.com)

---

## 6. Profil + Feature Upgrade Options

### Feature Tiers

| Tier | Price | Features |
|------|-------|----------|
| Free (7d) | $0 | AI plan, basic tracking, 4-5 workouts |
| Ishrana | TBD | Free + meal tracking + meal plans |
| Pro | TBD | Ishrana + AI coach chat |

### Upgrade Flow
1. User goes to Profile → "Nadogradi na Ishranu" or "Nadogradi na Pro"
2. Button disabled if already owned
3. When tapped:
   - If nutrition: sets `feature_tier = 'nutrition'` and `has_nutrition = true`
   - If pro: sets `feature_tier = 'pro'` and `has_nutrition = true`
4. Supabase upsert to `user_profiles`
5. UI reloads with new features unlocked

---

## 7. Architecture Changes

### New Files

- `Services/OnboardingService.swift` — AI plan generation + save
- `Services/FeatureGateService.swift` — check trial, check tier
- `ViewModels/ProfileViewModel.swift` — profile data, stats, streak
- `Views/OnboardingView.swift` — multi-step onboarding (8 screens)
- `Views/ProfileView.swift` — profile screen with stats + settings
- `Views/EnterWeightView.swift` — modal for weight input per exercise

### Modified Files

- `Services/AuthService.swift` — pass user_id after login
- `Services/SupabaseTypes.swift` — add UserProfileData
- `ViewModels/WorkoutViewModel.swift` — filter by auth user, limit free trial
- `ViewModels/MealViewModel.swift` — gate by has_nutrition
- `ViewModels/CoachChatViewModel.swift` — gate by pro tier
- `Views/HomeView.swift` — add Profile tab (5th tab or settings icon)
- `Views/AuthView.swift` — redirect to onboarding if no profile
- `TraningPlan2026App.swift` — check onboarding status on launch

### Views/CoachChatView.swift
- Already exists, just gate behind Pro tier

---

## 8. User Flow

```
App Launch
    │
    ├── Auth (login/register)
    │     │
    │     └── Check if user has profile
    │           │
    │           ├── No → Onboarding (8 screens)
    │           │         │
    │           │         └── AI Plan Generator → Home
    │           │
    │           └── Yes → Home
    │                    │
    │                    ├── Tab 0: Dashboard
    │                    ├── Tab 1: Workouts (free or pro)
    │                    ├── Tab 2: Meals (if has_nutrition)
    │                    ├── Tab 3: Progress
    │                    └── Tab 4: Profile (stats, settings, upgrades)
    │
    └── If trial expired → block new workout generation
        Show upgrade prompt in Profile
```
