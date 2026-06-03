import Foundation
import Supabase

class UserWorkoutService {
    private let supabase: SupabaseClient
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    func saveWorkout(_ workout: Workout) async throws {
        let plansResponse: [WorkoutPlanMetadata] = try await supabase
            .from("workout_plans")
            .select()
            .execute()
            .value
        
        let planId: String
        if let existingPlan = plansResponse.first {
            planId = existingPlan.plan_id
        } else {
            planId = "102234"
            let newPlan = WorkoutPlanMetadata(
                plan_id: planId,
                name: "Program",
                start_date: nil,
                end_date: nil,
                notes: nil
            )
            try await supabase
                .from("workout_plans")
                .upsert(newPlan)
                .execute()
        }
        
        struct WorkoutDayOnly: Codable {
            let day: Int
        }
        
        let workoutsResponse: [WorkoutDayOnly] = try await supabase
            .from("workouts")
            .select("day")
            .eq("plan_id", value: planId)
            .execute()
            .value
        
        let maxDay = workoutsResponse.map { $0.day }.max() ?? 0
        let newDay = maxDay + 1
        
        let workoutData = WorkoutMetadata(
            workout_id: workout.id,
            plan_id: planId,
            day: newDay,
            name: workout.name,
            workout_date: workout.date,
            is_completed: true,
            duration: workout.duration,
            notes: workout.notes
        )
        
        try await supabase
            .from("workouts")
            .delete()
            .eq("workout_id", value: workout.id)
            .eq("plan_id", value: planId)
            .execute()
        
        try await supabase
            .from("workouts")
            .insert(workoutData)
            .execute()
        
        if !workout.exercises.isEmpty {
            let exercisesData = workout.exercises.map { exercise in
                ExerciseData(
                    exercise_id: exercise.id,
                    workout_id: workout.id,
                    plan_id: planId,
                    name: exercise.name,
                    sets: exercise.sets,
                    reps: exercise.reps,
                    weight: exercise.weight,
                    duration: exercise.duration,
                    notes: exercise.notes
                )
            }
            
            try await supabase
                .from("exercises")
                .delete()
                .eq("workout_id", value: workout.id)
                .eq("plan_id", value: planId)
                .execute()
            
            try await supabase
                .from("exercises")
                .insert(exercisesData)
                .execute()
        }
    }
    
    func listenToWorkouts(completion: @escaping ([Workout]) -> Void) {
        Task {
            do {
                let workoutsData: [WorkoutMetadata] = try await supabase
                    .from("workouts")
                    .select()
                    .order("workout_date", ascending: false)
                    .execute()
                    .value
                
                var result: [Workout] = []
                for workoutData in workoutsData {
                    let exercisesData: [ExerciseData] = try await supabase
                        .from("exercises")
                        .select()
                        .eq("workout_id", value: workoutData.workout_id)
                        .eq("plan_id", value: workoutData.plan_id)
                        .execute()
                        .value
                    
                    let exercises = exercisesData.map { exerciseData in
                        Workout.Exercise(
                            id: exerciseData.exercise_id,
                            name: exerciseData.name,
                            sets: exerciseData.sets,
                            reps: exerciseData.reps,
                            weight: exerciseData.weight,
                            duration: exerciseData.duration,
                            notes: exerciseData.notes
                        )
                    }
                    
                    let workout = Workout(
                        id: workoutData.workout_id,
                        name: workoutData.name,
                        date: workoutData.workout_date ?? Date(),
                        exercises: exercises,
                        isCompleted: workoutData.is_completed ?? true,
                        notes: workoutData.notes,
                        duration: workoutData.duration
                    )
                    result.append(workout)
                }
                
                completion(result)
            } catch {
                completion([])
            }
        }
    }
    
    func deleteWorkout(_ workout: Workout) async throws {
        struct WorkoutPlanIdOnly: Codable {
            let plan_id: String
        }
        
        let workoutsResponse: [WorkoutPlanIdOnly] = try await supabase
            .from("workouts")
            .select("plan_id")
            .eq("workout_id", value: workout.id)
            .execute()
            .value
        
        guard let planId = workoutsResponse.first?.plan_id else {
            throw NSError(domain: "WorkoutNotFound", code: 404)
        }
        
        try await supabase
            .from("exercises")
            .delete()
            .eq("workout_id", value: workout.id)
            .eq("plan_id", value: planId)
            .execute()
        
        try await supabase
            .from("workouts")
            .delete()
            .eq("workout_id", value: workout.id)
            .eq("plan_id", value: planId)
            .execute()
    }
}
