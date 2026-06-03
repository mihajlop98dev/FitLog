-- Add tables for persisted "4-workout queue" and progress pointer
-- Run this script in Supabase SQL editor if your schema was already created.

CREATE TABLE IF NOT EXISTS user_training_plan_queue (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    source_workout_id TEXT NOT NULL,
    name TEXT NOT NULL,
    position INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

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
    updated_at TIMESTAMPTZ DEFAULT NOW(),Multiple commands produce '/Volumes/Extreme Pro/DerivedData/TraningPlan2026-fvgrhpdbuseqqfhdbmnjbjssfjfk/Build/Products/Debug-iphoneos/TraningPlan2026.app/Info.plist'

    FOREIGN KEY (queue_workout_id) REFERENCES user_training_plan_queue(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS user_training_plan_progress (
    id TEXT PRIMARY KEY,
    next_start_index INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_training_queue_position ON user_training_plan_queue(position);
CREATE INDEX IF NOT EXISTS idx_training_queue_exercises_qw ON user_training_plan_queue_exercises(queue_workout_id, position);

ALTER TABLE user_training_plan_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_training_plan_queue_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_training_plan_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations" ON user_training_plan_queue FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON user_training_plan_queue_exercises FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "Allow all operations" ON user_training_plan_progress FOR ALL USING (true) WITH CHECK (true);
