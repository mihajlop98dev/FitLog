-- FitLog Migration v2: User profiles, RLS, user_id columns
-- Pokreni u Supabase SQL Editor-u

-- 1. User profiles table
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

-- 2. Add user_id columns to existing user tables
ALTER TABLE user_workouts ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE user_meals ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE user_exercise_records ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE user_food_records ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE user_body_progress ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE user_training_plan_queue ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);
ALTER TABLE user_training_plan_queue_exercises ADD COLUMN IF NOT EXISTS user_id UUID;
ALTER TABLE user_training_plan_progress ADD COLUMN IF NOT EXISTS user_id UUID;

-- 3. RLS: user_profiles
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users manage own profile" ON user_profiles;
CREATE POLICY "Users manage own profile" ON user_profiles
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 4. RLS: user_workouts
DROP POLICY IF EXISTS "Allow all operations" ON user_workouts;
ALTER TABLE user_workouts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own workouts" ON user_workouts
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 5. RLS: user_meals
DROP POLICY IF EXISTS "Allow all operations" ON user_meals;
ALTER TABLE user_meals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own meals" ON user_meals
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 6. RLS: user_exercise_records
DROP POLICY IF EXISTS "Allow all operations" ON user_exercise_records;
ALTER TABLE user_exercise_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own exercise records" ON user_exercise_records
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 7. RLS: user_food_records
DROP POLICY IF EXISTS "Allow all operations" ON user_food_records;
ALTER TABLE user_food_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own food records" ON user_food_records
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 8. RLS: user_body_progress
DROP POLICY IF EXISTS "Users can view own body progress" ON user_body_progress;
DROP POLICY IF EXISTS "Users can insert own body progress" ON user_body_progress;
DROP POLICY IF EXISTS "Users can update own body progress" ON user_body_progress;
DROP POLICY IF EXISTS "Users can delete own body progress" ON user_body_progress;
ALTER TABLE user_body_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own body progress" ON user_body_progress
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 9. RLS: user_training_plan_queue
DROP POLICY IF EXISTS "Allow all operations" ON user_training_plan_queue;
ALTER TABLE user_training_plan_queue ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own queue" ON user_training_plan_queue
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 10. RLS: user_training_plan_queue_exercises
DROP POLICY IF EXISTS "Allow all operations" ON user_training_plan_queue_exercises;
ALTER TABLE user_training_plan_queue_exercises ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own queue exercises" ON user_training_plan_queue_exercises
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 11. RLS: user_training_plan_progress
DROP POLICY IF EXISTS "Allow all operations" ON user_training_plan_progress;
ALTER TABLE user_training_plan_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own progress" ON user_training_plan_progress
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 12. Source tables: PUBLIC READ ONLY (remove old allow-all policies)
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
