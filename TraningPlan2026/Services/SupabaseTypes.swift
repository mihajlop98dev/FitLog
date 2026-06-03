import Foundation
import Supabase

struct WorkoutPlanMetadata: Codable {
    let plan_id: String
    let name: String
    let start_date: Date?
    let end_date: Date?
    let notes: String?
}

struct WorkoutMetadata: Codable {
    let workout_id: String
    let plan_id: String
    let day: Int
    let name: String
    let workout_date: Date?
    let is_completed: Bool?
    let duration: Int?
    let notes: String?
}

struct ExerciseData: Codable {
    let exercise_id: String
    let workout_id: String
    let plan_id: String
    let name: String
    let sets: Int?
    let reps: Int?
    let weight: Double?
    let duration: Int?
    let notes: String?
}

struct ExerciseCatalogItem: Codable {
    let id: String
    let name: String
    let category: String?
    let normalized_name: String?
    let description: String?
    let instructions: String?
    let notes: String?
    let how_to: String?
    let execution_tips: String?
    let created_at: Date?
    let updated_at: Date?
}

struct ExerciseCatalogData: Codable {
    let name: String
}

struct MealPlanMetadata: Codable {
    let plan_id: String
    let name: String
    let start_date: Date?
    let end_date: Date?
    let notes: String?
}

struct MealData: Codable {
    let meal_id: String
    let plan_id: String
    let day: Int?
    let time: String
    let name: String
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let recipe: String?
    let notes: String?
}

struct FoodData: Codable {
    let food_id: String
    let meal_id: String
    let plan_id: String
    let name: String
    let quantity: String?
    let calories: Int?
}

struct UserMealData: Codable {
    let id: String
    let name: String
    let time: String
    let date: Date?
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let notes: String?
}

struct UserFoodData: Codable {
    let id: String
    let meal_id: String
    let name: String
    let quantity: String?
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
}

struct TrainingQueueWorkout: Codable {
    let id: String
    let sourceWorkoutId: String
    let name: String
    let position: Int
    let exercises: [Workout.Exercise]
}

struct TrainingQueueWorkoutData: Codable {
    let id: String
    let source_workout_id: String
    let name: String
    let position: Int
}

struct TrainingQueueExerciseData: Codable {
    let id: String
    let queue_workout_id: String
    let position: Int
    let name: String
    let sets: Int?
    let reps: Int?
    let weight: Double?
    let duration: Int?
    let notes: String?
}

struct TrainingQueueProgressData: Codable {
    let id: String
    let next_start_index: Int
}

struct BodyProgressData: Codable {
    let id: String
    let date: Date
    let weight: Double?
    let waist: Double?
    let chest: Double?
    let arm: Double?
    let photo_path: String?
    let photo_base64: String?
    let analysis_json: String?
    let comparison_json: String?
    let created_at: Date?
}

struct BodyProgressUpsertData: Codable {
    let id: String
    let date: Date
    let weight: Double?
    let waist: Double?
    let chest: Double?
    let arm: Double?
    let photo_path: String?
    let photo_base64: String?
    let analysis_json: String?
    let comparison_json: String?
}
