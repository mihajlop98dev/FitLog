import Foundation
import Supabase

class TrainingQueueService {
    private let supabase: SupabaseClient
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    func fetchTrainingPlanQueue() async throws -> [TrainingQueueWorkout] {
        let queueRows: [TrainingQueueWorkoutData] = try await supabase
            .from("user_training_plan_queue")
            .select()
            .order("position", ascending: true)
            .execute()
            .value
        
        var workouts: [TrainingQueueWorkout] = []
        for row in queueRows {
            let exercisesRows: [TrainingQueueExerciseData] = try await supabase
                .from("user_training_plan_queue_exercises")
                .select()
                .eq("queue_workout_id", value: row.id)
                .order("position", ascending: true)
                .execute()
                .value
            
            let exercises = exercisesRows.map { ex in
                Workout.Exercise(
                    id: ex.id,
                    name: ex.name,
                    sets: ex.sets,
                    reps: ex.reps,
                    weight: ex.weight,
                    duration: ex.duration,
                    notes: ex.notes
                )
            }
            
            workouts.append(
                TrainingQueueWorkout(
                    id: row.id,
                    sourceWorkoutId: row.source_workout_id,
                    name: row.name,
                    position: row.position,
                    exercises: exercises
                )
            )
        }
        
        return workouts
    }
    
    func replaceTrainingPlanQueue(with workouts: [TrainingQueueWorkout]) async throws {
        try await supabase
            .from("user_training_plan_queue_exercises")
            .delete()
            .neq("id", value: "")
            .execute()
        
        try await supabase
            .from("user_training_plan_queue")
            .delete()
            .neq("id", value: "")
            .execute()
        
        guard !workouts.isEmpty else { return }
        
        let queueRows = workouts.map { workout in
            TrainingQueueWorkoutData(
                id: workout.id,
                source_workout_id: workout.sourceWorkoutId,
                name: workout.name,
                position: workout.position
            )
        }
        
        try await supabase
            .from("user_training_plan_queue")
            .upsert(queueRows)
            .execute()
        
        var exerciseRows: [TrainingQueueExerciseData] = []
        for workout in workouts {
            for (index, exercise) in workout.exercises.enumerated() {
                exerciseRows.append(
                    TrainingQueueExerciseData(
                        id: UUID().uuidString,
                        queue_workout_id: workout.id,
                        position: index + 1,
                        name: exercise.name,
                        sets: exercise.sets,
                        reps: exercise.reps,
                        weight: exercise.weight,
                        duration: exercise.duration,
                        notes: exercise.notes
                    )
                )
            }
        }
        
        if !exerciseRows.isEmpty {
            try await supabase
                .from("user_training_plan_queue_exercises")
                .upsert(exerciseRows)
                .execute()
        }
    }
    
    func deleteTrainingPlanQueueWorkout(id: String) async throws {
        try await supabase
            .from("user_training_plan_queue_exercises")
            .delete()
            .eq("queue_workout_id", value: id)
            .execute()
        
        try await supabase
            .from("user_training_plan_queue")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    func fetchTrainingPlanProgressIndex() async throws -> Int? {
        let rows: [TrainingQueueProgressData] = try await supabase
            .from("user_training_plan_progress")
            .select()
            .eq("id", value: "default")
            .execute()
            .value
        return rows.first?.next_start_index
    }
    
    func saveTrainingPlanProgressIndex(_ index: Int) async throws {
        let row = TrainingQueueProgressData(id: "default", next_start_index: index)
        try await supabase
            .from("user_training_plan_progress")
            .upsert(row)
            .execute()
    }
}
