-- Supabase PostgreSQL Schema za TraningPlan2026
-- Pokreni ovu skriptu u Supabase SQL Editor-u

-- Workout Plans
CREATE TABLE IF NOT EXISTS workout_plans (
    plan_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Workouts (treningi u planu)
CREATE TABLE IF NOT EXISTS workouts (
    workout_id TEXT NOT NULL,
    plan_id TEXT NOT NULL,
    day INTEGER NOT NULL,
    name TEXT NOT NULL,
    workout_date TIMESTAMPTZ,
    is_completed BOOLEAN DEFAULT TRUE, -- Svi treningi su završeni
    duration INTEGER, -- u minutama
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (workout_id, plan_id),
    FOREIGN KEY (plan_id) REFERENCES workout_plans(plan_id) ON DELETE CASCADE
);

-- Exercises (vežbe u treningu)
CREATE TABLE IF NOT EXISTS exercises (
    exercise_id TEXT NOT NULL,
    workout_id TEXT NOT NULL,
    plan_id TEXT NOT NULL,
    name TEXT NOT NULL,
    sets INTEGER,
    reps INTEGER,
    weight DOUBLE PRECISION,
    duration INTEGER, -- u sekundama
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (exercise_id, workout_id, plan_id),
    FOREIGN KEY (workout_id, plan_id) REFERENCES workouts(workout_id, plan_id) ON DELETE CASCADE
);

-- Meal Plans
CREATE TABLE IF NOT EXISTS meal_plans (
    plan_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Meals (obroci u planu)
CREATE TABLE IF NOT EXISTS meals (
    meal_id TEXT NOT NULL,
    plan_id TEXT NOT NULL,
    day INTEGER,
    time TEXT NOT NULL, -- "Doručak", "Ručak", "Večera"
    name TEXT NOT NULL,
    calories INTEGER,
    protein DOUBLE PRECISION,
    carbs DOUBLE PRECISION,
    fat DOUBLE PRECISION,
    recipe TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (meal_id, plan_id),
    FOREIGN KEY (plan_id) REFERENCES meal_plans(plan_id) ON DELETE CASCADE
);

-- Foods (namirnice u obroku)
CREATE TABLE IF NOT EXISTS foods (
    food_id TEXT NOT NULL,
    meal_id TEXT NOT NULL,
    plan_id TEXT NOT NULL,
    name TEXT NOT NULL,
    quantity TEXT,
    calories INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (food_id, meal_id, plan_id),
    FOREIGN KEY (meal_id, plan_id) REFERENCES meals(meal_id, plan_id) ON DELETE CASCADE
);

-- User Workouts (završeni treningi koje korisnik dodaje)
CREATE TABLE IF NOT EXISTS user_workouts (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    name TEXT NOT NULL,
    date TIMESTAMPTZ NOT NULL,
    is_completed BOOLEAN DEFAULT false,
    duration INTEGER, -- u minutama
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Meals (dodatni obroci koje korisnik dodaje)
CREATE TABLE IF NOT EXISTS user_meals (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    name TEXT NOT NULL,
    time TEXT NOT NULL,
    date TIMESTAMPTZ,
    calories INTEGER,
    protein DOUBLE PRECISION,
    carbs DOUBLE PRECISION,
    fat DOUBLE PRECISION,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Exercise Records (vežbe u user workout-u)
CREATE TABLE IF NOT EXISTS user_exercise_records (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    workout_id TEXT NOT NULL,
    name TEXT NOT NULL,
    sets INTEGER,
    reps INTEGER,
    weight DOUBLE PRECISION,
    duration INTEGER,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (workout_id) REFERENCES user_workouts(id) ON DELETE CASCADE
);

-- User Food Records (namirnice u user meal-u)
CREATE TABLE IF NOT EXISTS user_food_records (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    meal_id TEXT NOT NULL,
    name TEXT NOT NULL,
    quantity TEXT,
    calories INTEGER,
    protein DOUBLE PRECISION,
    carbs DOUBLE PRECISION,
    fat DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (meal_id) REFERENCES user_meals(id) ON DELETE CASCADE
);

-- Exercise Catalog (katalog svih dostupnih vežbi)
CREATE TABLE IF NOT EXISTS exercise_catalog (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    name TEXT NOT NULL UNIQUE,
    category TEXT, -- Noge, Ramena, Ruke, Biceps, Triceps, Grudi, Leđa, Trbuh, Kardio, itd.
    normalized_name TEXT, -- Normalizovano ime za identifikaciju duplikata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User Training Plan Queue (trenutna 4 treninga koja se rade redom)
CREATE TABLE IF NOT EXISTS user_training_plan_queue (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    source_workout_id TEXT NOT NULL,
    name TEXT NOT NULL,
    position INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vežbe za queue treninge
CREATE TABLE IF NOT EXISTS user_training_plan_queue_exercises (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    queue_workout_id TEXT NOT NULL,
    position INTEGER NOT NULL,
    name TEXT NOT NULL,
    sets INTEGER,
    reps INTEGER,
    weight DOUBLE PRECISION,
    duration INTEGER,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    FOREIGN KEY (queue_workout_id) REFERENCES user_training_plan_queue(id) ON DELETE CASCADE
);

-- Pokazivač gde je korisnik stao (sledeći indeks za batch od 4)
CREATE TABLE IF NOT EXISTS user_training_plan_progress (
    id TEXT PRIMARY KEY,
    next_start_index INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indeksi za brže pretrage
CREATE INDEX IF NOT EXISTS idx_workouts_plan_id ON workouts(plan_id);
CREATE INDEX IF NOT EXISTS idx_workouts_date ON workouts(workout_date);
CREATE INDEX IF NOT EXISTS idx_exercises_workout ON exercises(workout_id, plan_id);
CREATE INDEX IF NOT EXISTS idx_meals_plan_id ON meals(plan_id);
CREATE INDEX IF NOT EXISTS idx_meals_time ON meals(time);
CREATE INDEX IF NOT EXISTS idx_foods_meal ON foods(meal_id, plan_id);
CREATE INDEX IF NOT EXISTS idx_user_workouts_date ON user_workouts(date);
CREATE INDEX IF NOT EXISTS idx_user_meals_date ON user_meals(date);
CREATE INDEX IF NOT EXISTS idx_exercise_catalog_name ON exercise_catalog(name);
CREATE INDEX IF NOT EXISTS idx_exercise_catalog_category ON exercise_catalog(category);
CREATE INDEX IF NOT EXISTS idx_exercise_catalog_normalized ON exercise_catalog(normalized_name);
CREATE INDEX IF NOT EXISTS idx_training_queue_position ON user_training_plan_queue(position);
CREATE INDEX IF NOT EXISTS idx_training_queue_exercises_qw ON user_training_plan_queue_exercises(queue_workout_id, position);

-- Row Level Security (RLS) - omogući pristup svima (možeš kasnije ograničiti)
ALTER TABLE workout_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_exercise_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_food_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_training_plan_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_training_plan_queue_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_training_plan_progress ENABLE ROW LEVEL SECURITY;

-- Policy: Dozvoli sve operacije svima (za sada - možeš kasnije ograničiti)
CREATE POLICY "Allow all operations" ON workout_plans FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON workouts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON exercises FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON meal_plans FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON meals FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON foods FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON user_workouts FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON user_meals FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON user_exercise_records FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON user_food_records FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON exercise_catalog FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON user_training_plan_queue FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON user_training_plan_queue_exercises FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON user_training_plan_progress FOR ALL USING (true) WITH CHECK (true);