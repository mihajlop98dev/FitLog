# Onboarding, Profile & AI Plan Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement onboarding flow, profile screen, AI plan generator, user data isolation, feature tiers, and localization.

**Architecture:** MVVM with Supabase backend, OpenAI for plan generation, SwiftUI for UI.

**Tech Stack:** SwiftUI, Supabase, OpenAI, LocalAuthentication

---

### Phase 1: Database & RLS

### Task 1: SQL Migration - New Tables + RLS Policies

**Files:**
- Create: `scripts/fitlog_migration_v2.sql`

- [ ] **Step 1: Write migration SQL**

Write the following to `scripts/fitlog_migration_v2.sql`:

```sql
-- User profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id),
    name TEXT,
    age INT,
    gender TEXT,
    weight_kg DOUBLE PRECISION,
    height_cm DOUBLE PRECISION,
    goal TEXT NOT NULL,
    level TEXT NOT NULL,
    days_per_week INT NOT NULL,
    equipment TEXT[] NOT NULL DEFAULT '{}',
    injuries TEXT[] DEFAULT '{}',
    has_nutrition BOOLEAN DEFAULT false,
    meals_per_day INT,
    allergies TEXT,
    motivation TEXT,
    trial_end_date TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days',
    feature_tier TEXT NOT NULL DEFAULT 'free',
    streak_count INT DEFAULT 0,
    last_activity_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add user_id to existing user_* tables
ALTER TABLE user_workouts ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE user_meals ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE user_exercise_records ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE user_food_records ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE user_body_progress ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE user_training_plan_queue ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE user_training_plan_queue_exercises ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE user_training_plan_progress ADD COLUMN IF NOT EXISTS user_id UUID;

-- RLS: user_profiles
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own profile" ON user_profiles;
CREATE POLICY "Users manage own profile" ON user_profiles
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RLS: user_workouts
DROP POLICY IF EXISTS "Allow all operations" ON user_workouts;
CREATE POLICY "Users manage own workouts" ON user_workouts
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RLS: user_meals
DROP POLICY IF EXISTS "Allow all operations" ON user_meals;
CREATE POLICY "Users manage own meals" ON user_meals
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RLS: user_exercise_records
DROP POLICY IF EXISTS "Allow all operations" ON user_exercise_records;
CREATE POLICY "Users manage own exercise records" ON user_exercise_records
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RLS: user_food_records
DROP POLICY IF EXISTS "Allow all operations" ON user_food_records;
CREATE POLICY "Users manage own food records" ON user_food_records
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RLS: user_body_progress
DROP POLICY IF EXISTS "Users can view own body progress" ON user_body_progress;
DROP POLICY IF EXISTS "Users can insert own body progress" ON user_body_progress;
DROP POLICY IF EXISTS "Users can update own body progress" ON user_body_progress;
DROP POLICY IF EXISTS "Users can delete own body progress" ON user_body_progress;
CREATE POLICY "Users manage own body progress" ON user_body_progress
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RLS: user_training_plan_queue
DROP POLICY IF EXISTS "Allow all operations" ON user_training_plan_queue;
CREATE POLICY "Users manage own queue" ON user_training_plan_queue
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RLS: user_training_plan_queue_exercises
DROP POLICY IF EXISTS "Allow all operations" ON user_training_plan_queue_exercises;
CREATE POLICY "Users manage own queue exercises" ON user_training_plan_queue_exercises
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- RLS: user_training_plan_progress
DROP POLICY IF EXISTS "Allow all operations" ON user_training_plan_progress;
CREATE POLICY "Users manage own progress" ON user_training_plan_progress
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Keep source tables public (read only)
DROP POLICY IF EXISTS "Allow all operations" ON workout_plans;
DROP POLICY IF EXISTS "Allow all operations" ON workouts;
DROP POLICY IF EXISTS "Allow all operations" ON exercises;
DROP POLICY IF EXISTS "Allow all operations" ON exercise_catalog;
DROP POLICY IF EXISTS "Allow all operations" ON meal_plans;
DROP POLICY IF EXISTS "Allow all operations" ON meals;
DROP POLICY IF EXISTS "Allow all operations" ON foods;

CREATE POLICY "Public read" ON workout_plans FOR SELECT USING (true);
CREATE POLICY "Public read" ON workouts FOR SELECT USING (true);
CREATE POLICY "Public read" ON exercises FOR SELECT USING (true);
CREATE POLICY "Public read" ON exercise_catalog FOR SELECT USING (true);
CREATE POLICY "Public read" ON meal_plans FOR SELECT USING (true);
CREATE POLICY "Public read" ON meals FOR SELECT USING (true);
CREATE POLICY "Public read" ON foods FOR SELECT USING (true);
```

- [ ] **Step 2: Update gitignore**

Add the migration file to git (not gitignored since it's important).

```bash
git add scripts/fitlog_migration_v2.sql
```

---

### Phase 2: Service Layer (Swift)

### Task 2: Add UserProfileData + FeatureGateService + OnboardingService types

**Files:**
- Modify: `TraningPlan2026/Services/SupabaseTypes.swift`
- Create: `TraningPlan2026/Services/FeatureGateService.swift`

- [ ] **Step 1: Add UserProfileData to SupabaseTypes**

```swift
import Foundation

struct UserProfileData: Codable {
    let id: String?
    let user_id: String
    let name: String?
    let age: Int?
    let gender: String?
    let weight_kg: Double?
    let height_cm: Double?
    let goal: String
    let level: String
    let days_per_week: Int
    let equipment: [String]
    let injuries: [String]?
    let has_nutrition: Bool
    let meals_per_day: Int?
    let allergies: String?
    let motivation: String?
    let trial_end_date: String
    let feature_tier: String
    let streak_count: Int?
    let last_activity_date: String?
}
```

- [ ] **Step 2: Create FeatureGateService**

```swift
import Foundation
import Supabase

@MainActor
class FeatureGateService: ObservableObject {
    @Published var profile: UserProfileData?
    @Published var isLoading = false
    
    private let supabase = SupabaseConfig.shared.supabase
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
    }
    
    func loadProfile() async {
        isLoading = true
        do {
            let profiles: [UserProfileData] = try await supabase
                .from("user_profiles")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            profile = profiles.first
        } catch {
            print("Failed to load profile: \(error)")
        }
        isLoading = false
    }
    
    var hasNutrition: Bool {
        profile?.has_nutrition ?? false
    }
    
    var isPro: Bool {
        profile?.feature_tier == "pro"
    }
    
    var isTrialValid: Bool {
        guard let trialEndStr = profile?.trial_end_date else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        guard let trialEnd = formatter.date(from: trialEndStr) else { return true }
        return Date() < trialEnd
    }
    
    var canGenerateWorkouts: Bool {
        isTrialValid || isPro
    }
    
    func updateFeatureTier(_ tier: String, hasNutrition: Bool) async {
        do {
            try await supabase
                .from("user_profiles")
                .update(["feature_tier": tier, "has_nutrition": hasNutrition])
                .eq("user_id", value: userId)
                .execute()
            profile?.feature_tier = tier
            profile?.has_nutrition = hasNutrition
        } catch {
            print("Failed to update tier: \(error)")
        }
    }
}
```

---

### Task 3: Update SupabaseService + Services to use user_id

**Files:**
- Modify: `TraningPlan2026/Services/UserWorkoutService.swift`
- Modify: `TraningPlan2026/Services/UserMealService.swift`
- Modify: `TraningPlan2026/Services/BodyProgressService.swift`
- Modify: `TraningPlan2026/Services/TrainingQueueService.swift`

Each service needs a `userId: String` parameter. Add it in init:

```swift
class UserWorkoutService {
    private let supabase: SupabaseClient
    private let userId: String
    
    init(supabase: SupabaseClient, userId: String) {
        self.supabase = supabase
        self.userId = userId
    }
```

Then add `userId` to all Supabase queries:

```swift
.eq("user_id", value: userId)
```

And on insert/upsert:

```swift
var data = modelData
// Ensure user_id is set
```

---

### Phase 3: Onboarding UI

### Task 4: Create OnboardingView with 8 screens

**Files:**
- Create: `TraningPlan2026/Views/OnboardingView.swift`
- Create: `TraningPlan2026/Services/OnboardingService.swift`

OnboardingView is a multi-step form with 8 steps, each as a separate @ViewBuilder section. Full implementation TBD in actual code.

---

### Phase 4: AI Plan Generator

### Task 5: Create AI Plan Generator

**Files:**
- Create: `TraningPlan2026/Services/PlanGeneratorService.swift`

Uses OpenAI gpt-4o-mini to generate personalized plans from template workouts.

---

### Phase 5: Profile Screen

### Task 6: Create ProfileView + ProfileViewModel

**Files:**
- Create: `TraningPlan2026/ViewModels/ProfileViewModel.swift`
- Create: `TraningPlan2026/Views/ProfileView.swift`

---

### Phase 6: Navigation + Feature Gates

### Task 7: Update HomeView + App flow

**Files:**
- Modify: `TraningPlan2026/TraningPlan2026App.swift`
- Modify: `TraningPlan2026/Views/HomeView.swift`
- Modify: `TraningPlan2026/Views/AuthView.swift`
- Modify: `TraningPlan2026/ViewModels/WorkoutViewModel.swift`
- Modify: `TraningPlan2026/ViewModels/MealViewModel.swift`
- Modify: `TraningPlan2026/ViewModels/CoachChatViewModel.swift`

Route to onboarding if no profile, add Profile tab, gate features.

---

### Phase 7: Localization

### Task 8: Add localization files

**Files:**
- Create: `TraningPlan2026/en.lproj/Localizable.strings`
- Create: `TraningPlan2026/sr.lproj/Localizable.strings`
- Modify: Various views to use `LocalizedStringKey`

---

### Phase 8: Backfill user_id for existing user

### Task 9: Run migration + backfill

Run SQL in Supabase dashboard. Then run backfill script to assign all existing user data to mihajlop98dev@outlook.com.
