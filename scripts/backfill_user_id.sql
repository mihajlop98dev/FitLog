-- Backfill user_id za postojece podatke
-- Zameni USER_ID sa stvarnim UUID-jem korisnika

DO $$
DECLARE
    target_user_id UUID := 'aa783799-c0b8-4439-ada2-77f914dbf10c';
BEGIN

    UPDATE user_workouts SET user_id = target_user_id WHERE user_id IS NULL;
    RAISE NOTICE 'user_workouts: % updated', (SELECT COUNT(*) FROM user_workouts WHERE user_id = target_user_id);

    UPDATE user_meals SET user_id = target_user_id WHERE user_id IS NULL;
    RAISE NOTICE 'user_meals: % updated', (SELECT COUNT(*) FROM user_meals WHERE user_id = target_user_id);

    UPDATE user_exercise_records SET user_id = target_user_id WHERE user_id IS NULL;
    RAISE NOTICE 'user_exercise_records: % updated', (SELECT COUNT(*) FROM user_exercise_records WHERE user_id = target_user_id);

    UPDATE user_food_records SET user_id = target_user_id WHERE user_id IS NULL;
    RAISE NOTICE 'user_food_records: % updated', (SELECT COUNT(*) FROM user_food_records WHERE user_id = target_user_id);

    UPDATE user_body_progress SET user_id = target_user_id WHERE user_id IS NULL;
    RAISE NOTICE 'user_body_progress: % updated', (SELECT COUNT(*) FROM user_body_progress WHERE user_id = target_user_id);

    UPDATE user_training_plan_queue SET user_id = target_user_id WHERE user_id IS NULL;
    RAISE NOTICE 'user_training_plan_queue: % updated', (SELECT COUNT(*) FROM user_training_plan_queue WHERE user_id = target_user_id);

    UPDATE user_training_plan_queue_exercises SET user_id = target_user_id WHERE user_id IS NULL;
    RAISE NOTICE 'user_training_plan_queue_exercises: % updated', (SELECT COUNT(*) FROM user_training_plan_queue_exercises WHERE user_id = target_user_id);

    UPDATE user_training_plan_progress SET user_id = target_user_id WHERE user_id IS NULL;
    RAISE NOTICE 'user_training_plan_progress: % updated', (SELECT COUNT(*) FROM user_training_plan_progress WHERE user_id = target_user_id);

END $$;
