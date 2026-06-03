import Foundation
import Supabase

class WorkoutPlanService {
    private let supabase: SupabaseClient
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    func fetchWorkoutPlans() async throws -> [WorkoutPlan] {
        let plansResponse: [WorkoutPlanMetadata] = try await supabase
            .from("workout_plans")
            .select()
            .execute()
            .value
        
        guard let planData = plansResponse.first else { return [] }
        
        let workoutsResponse: [WorkoutMetadata] = try await supabase
            .from("workouts")
            .select()
            .eq("plan_id", value: planData.plan_id)
            .execute()
            .value
        
        var workouts: [WorkoutPlan.WorkoutPlanItem] = []
        for workoutData in workoutsResponse {
            let dateString: String?
            if let date = workoutData.workout_date {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
                dateString = formatter.string(from: date)
            } else {
                dateString = nil
            }
            
            let workout = WorkoutPlan.WorkoutPlanItem(
                id: workoutData.workout_id,
                day: workoutData.day,
                name: workoutData.name,
                date: dateString,
                exercises: [],
                notes: workoutData.notes
            )
            workouts.append(workout)
        }
        
        workouts.sort { workout1, workout2 in
            guard let date1 = workout1.workoutDate, let date2 = workout2.workoutDate else {
                return workout1.day > workout2.day
            }
            return date1 > date2
        }
        
        let plan = WorkoutPlan(
            planId: planData.plan_id,
            name: planData.name,
            workouts: workouts,
            startDate: planData.start_date,
            endDate: planData.end_date,
            notes: planData.notes
        )
        
        return [plan]
    }
    
    func fetchExercisesForWorkout(planId: String, workoutId: String) async throws -> [Workout.Exercise] {
        let response: [ExerciseData] = try await supabase
            .from("exercises")
            .select()
            .eq("plan_id", value: planId)
            .eq("workout_id", value: workoutId)
            .execute()
            .value
        
        return response.map { exerciseData in
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
    }
    
    func fetchExerciseCount(planId: String, workoutId: String) async throws -> Int {
        let exercises: [ExerciseData] = try await supabase
            .from("exercises")
            .select("exercise_id")
            .eq("plan_id", value: planId)
            .eq("workout_id", value: workoutId)
            .execute()
            .value
        return exercises.count
    }
    
    func fetchAllExercisesFromPlan(planId: String) async throws -> [Workout.Exercise] {
        let response: [ExerciseData] = try await supabase
            .from("exercises")
            .select()
            .eq("plan_id", value: planId)
            .execute()
            .value
        
        return response.map { exerciseData in
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
    }
}
