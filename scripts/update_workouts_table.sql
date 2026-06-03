-- Ažuriraj workouts tabelu da uključi is_completed i duration polja
-- Pokreni ovu skriptu u Supabase SQL Editor-u

-- Dodaj is_completed polje ako ne postoji
ALTER TABLE workouts 
ADD COLUMN IF NOT EXISTS is_completed BOOLEAN DEFAULT TRUE;

-- Dodaj duration polje ako ne postoji
ALTER TABLE workouts 
ADD COLUMN IF NOT EXISTS duration INTEGER;

-- Postavi sve postojeće treninge kao završene
UPDATE workouts 
SET is_completed = TRUE 
WHERE is_completed IS NULL;
