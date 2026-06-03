//
//  SupabaseService.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import Foundation
import Supabase

class SupabaseService {
    private let supabase: SupabaseClient
    private let bodyProgressBucket = "body-progress-photos"
    
    init() {
        // Koristi shared Supabase klijent iz SupabaseConfig
        self.supabase = SupabaseConfig.shared.supabase
    }
    
    // MARK: - Workout Plans
    
    func fetchWorkoutPlans() async throws -> [WorkoutPlan] {
        do {
            // Učitaj plan metadata
            let plansResponse: [WorkoutPlanMetadata] = try await supabase
                .from("workout_plans")
                .select()
                .execute()
                .value
            
            guard let planData = plansResponse.first else {
                return []
            }
            
            // Učitaj workouts za plan
            let workoutsResponse: [WorkoutMetadata] = try await supabase
                .from("workouts")
                .select()
                .eq("plan_id", value: planData.plan_id)
                .execute()
                .value
            
            // Konvertuj u WorkoutPlan strukturu
            var workouts: [WorkoutPlan.WorkoutPlanItem] = []
            for workoutData in workoutsResponse {
                // Vežbe ćemo učitati tek kada treba (lazy loading)
                // Konvertuj Date u ISO string za WorkoutPlanItem
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
                    exercises: [], // Prazna lista - učitavamo tek kada treba
                    notes: workoutData.notes
                )
                workouts.append(workout)
            }
            
            // Sortiraj po datumu: od najnovijeg ka najstarijem (poslednji dan prvo)
            workouts.sort { workout1, workout2 in
                guard let date1 = workout1.workoutDate, let date2 = workout2.workoutDate else {
                    // Ako nema datuma, sortiraj po danu (najveći dan prvo)
                    return workout1.day > workout2.day
                }
                // Sortiraj po datumu: najnoviji prvo (poslednji dan)
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
        } catch {
            print("❌ Error fetching workout plans: \(error)")
            throw error
        }
    }
    
    func fetchExercisesForWorkout(planId: String, workoutId: String) async throws -> [Workout.Exercise] {
        do {
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
        } catch {
            print("❌ Error fetching exercises: \(error)")
            throw error
        }
    }
    
    func fetchExerciseCount(planId: String, workoutId: String) async throws -> Int {
        do {
            // Učitaj samo exercise_id za brže učitavanje
            let exercises: [ExerciseData] = try await supabase
                .from("exercises")
                .select("exercise_id")
                .eq("plan_id", value: planId)
                .eq("workout_id", value: workoutId)
                .execute()
                .value
            
            return exercises.count
        } catch {
            print("❌ Error fetching exercise count: \(error)")
            return 0
        }
    }
    
    // Učitaj sve vežbe iz svih treninga u planu odjednom (efikasnije)
    func fetchAllExercisesFromPlan(planId: String) async throws -> [Workout.Exercise] {
        do {
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
        } catch {
            print("❌ Error fetching all exercises from plan: \(error)")
            throw error
        }
    }
    
    // MARK: - Exercise Catalog
    
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
    
    func fetchAllExercisesFromCatalog() async throws -> [String] {
        do {
            let response: [ExerciseCatalogItem] = try await supabase
                .from("exercise_catalog")
                .select()
                .order("name", ascending: true)
                .execute()
                .value
            
            return response.map { $0.name }
        } catch {
            print("❌ Error fetching exercises from catalog: \(error)")
            throw error
        }
    }
    
    func fetchExercisesByCategory() async throws -> [String: [String]] {
        do {
            let response: [ExerciseCatalogItem] = try await supabase
                .from("exercise_catalog")
                .select()
                .order("name", ascending: true)
                .execute()
                .value
            
            var categorized: [String: [String]] = [:]
            for item in response {
                let category = item.category ?? "Ostalo"
                if categorized[category] == nil {
                    categorized[category] = []
                }
                categorized[category]?.append(item.name)
            }
            
            return categorized
        } catch {
            print("❌ Error fetching exercises by category: \(error)")
            throw error
        }
    }
    
    func fetchExerciseGuidesFromCatalog() async throws -> [String: String] {
        do {
            let response: [ExerciseCatalogItem] = try await supabase
                .from("exercise_catalog")
                .select()
                .execute()
                .value
            
            var guides: [String: String] = [:]
            for item in response {
                let guide = item.instructions ?? item.description ?? item.how_to ?? item.execution_tips ?? item.notes
                guard let guide, !guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                guides[item.name] = guide
            }
            return guides
        } catch {
            print("❌ Error fetching exercise guides from catalog: \(error)")
            throw error
        }
    }
    
    struct ExerciseCatalogData: Codable {
        let name: String
    }
    
    func addExerciseToCatalog(name: String) async throws {
        do {
            let exerciseData = ExerciseCatalogData(name: name)
            
            try await supabase
                .from("exercise_catalog")
                .upsert(exerciseData)
                .execute()
            
            print("✅ Exercise '\(name)' added to catalog")
        } catch {
            print("❌ Error adding exercise to catalog: \(error)")
            throw error
        }
    }
    
    // MARK: - Training Plan Queue (persisted 4-workout batch)
    
    func fetchTrainingPlanQueue() async throws -> [TrainingQueueWorkout] {
        do {
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
        } catch {
            print("❌ Error fetching training queue: \(error)")
            throw error
        }
    }
    
    func replaceTrainingPlanQueue(with workouts: [TrainingQueueWorkout]) async throws {
        do {
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
        } catch {
            print("❌ Error replacing training queue: \(error)")
            throw error
        }
    }
    
    func deleteTrainingPlanQueueWorkout(id: String) async throws {
        do {
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
        } catch {
            print("❌ Error deleting queue workout: \(error)")
            throw error
        }
    }
    
    func fetchTrainingPlanProgressIndex() async throws -> Int? {
        do {
            let rows: [TrainingQueueProgressData] = try await supabase
                .from("user_training_plan_progress")
                .select()
                .eq("id", value: "default")
                .execute()
                .value
            
            return rows.first?.next_start_index
        } catch {
            print("❌ Error fetching training queue progress: \(error)")
            throw error
        }
    }
    
    func saveTrainingPlanProgressIndex(_ index: Int) async throws {
        do {
            let row = TrainingQueueProgressData(id: "default", next_start_index: index)
            try await supabase
                .from("user_training_plan_progress")
                .upsert(row)
                .execute()
        } catch {
            print("❌ Error saving training queue progress: \(error)")
            throw error
        }
    }
    
    // MARK: - Meal Plans
    
    func fetchMealPlans() async throws -> [MealPlan] {
        do {
            // Učitaj plan metadata
            let plansResponse: [MealPlanMetadata] = try await supabase
                .from("meal_plans")
                .select()
                .execute()
                .value
            
            guard let planData = plansResponse.first else {
                return []
            }
            
            // Učitaj meals za plan
            let mealsResponse: [MealData] = try await supabase
                .from("meals")
                .select()
                .eq("plan_id", value: planData.plan_id)
                .execute()
                .value
            
            // Učitaj foods za sve meals
            var meals: [MealPlan.MealPlanItem] = []
            for mealData in mealsResponse {
                // Učitaj foods za ovaj meal
                let foodsResponse: [FoodData] = try await supabase
                    .from("foods")
                    .select()
                    .eq("plan_id", value: planData.plan_id)
                    .eq("meal_id", value: mealData.meal_id)
                    .execute()
                    .value
                
                let foods = foodsResponse.map { foodData in
                    Meal.FoodItem(
                        id: foodData.food_id,
                        name: foodData.name,
                        quantity: foodData.quantity,
                        calories: foodData.calories
                    )
                }
                
                let meal = MealPlan.MealPlanItem(
                    id: mealData.meal_id,
                    day: mealData.day,
                    time: mealData.time,
                    name: mealData.name,
                    foods: foods,
                    calories: mealData.calories,
                    protein: mealData.protein,
                    carbs: mealData.carbs,
                    fat: mealData.fat,
                    recipe: mealData.recipe,
                    notes: mealData.notes
                )
                meals.append(meal)
            }
            
            let plan = MealPlan(
                planId: planData.plan_id,
                name: planData.name,
                meals: meals,
                startDate: planData.start_date,
                endDate: planData.end_date,
                notes: planData.notes
            )
            
            return [plan]
        } catch {
            print("❌ Error fetching meal plans: \(error)")
            throw error
        }
    }
    
    // MARK: - User Workouts (sada se čuvaju u workouts tabeli)
    
    func saveWorkout(_ workout: Workout) async throws {
        // Pronađi plan_id (koristi postojeći plan ili kreiraj novi)
        let plansResponse: [WorkoutPlanMetadata] = try await supabase
            .from("workout_plans")
            .select()
            .execute()
            .value
        
        let planId: String
        if let existingPlan = plansResponse.first {
            planId = existingPlan.plan_id
        } else {
            // Ako nema plana, kreiraj novi
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
        
        // Pronađi najveći dan u planu (učitavamo samo "day")
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
        
        // Sačuvaj u workouts tabelu (ista tabela gde su već 175 treninga)
        // Koristimo WorkoutMetadata strukturu direktno (kao u addExerciseToCatalog)
        let workoutData = WorkoutMetadata(
            workout_id: workout.id,
            plan_id: planId,
            day: newDay,
            name: workout.name,
            workout_date: workout.date,
            is_completed: true, // Svi treningi su završeni
            duration: workout.duration,
            notes: workout.notes
        )
        
        // Upsert - koristimo .insert() umesto .upsert() jer možda .upsert() automatski vraća podatke
        // Prvo obriši postojeći workout (ako postoji)
        do {
            try await supabase
                .from("workouts")
                .delete()
                .eq("workout_id", value: workout.id)
                .eq("plan_id", value: planId)
                .execute()
        } catch {
            // Ignoriši grešku ako workout ne postoji
        }
        
        // Sada insert novi workout - .insert() ne vraća podatke automatski
        try await supabase
            .from("workouts")
            .insert(workoutData)
            .execute()
        
        // Sačuvaj exercises u exercises tabelu
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
            
            // Obriši stare vežbe za ovaj trening
            do {
                try await supabase
                    .from("exercises")
                    .delete()
                    .eq("workout_id", value: workout.id)
                    .eq("plan_id", value: planId)
                    .execute()
            } catch {
                // Ignoriši grešku ako vežbe ne postoje
            }
            
            // Insert nove vežbe - .insert() ne vraća podatke automatski
            try await supabase
                .from("exercises")
                .insert(exercisesData)
                .execute()
        }
    }
    
    func listenToWorkouts(completion: @escaping ([Workout]) -> Void) {
        // Učitaj sve workouts iz workouts tabele (gde su već 175 treninga iz plana)
        Task {
            do {
                // Učitaj sve workouts iz workouts tabele
                let workoutsData: [WorkoutMetadata] = try await supabase
                    .from("workouts")
                    .select()
                    .order("workout_date", ascending: false)
                    .execute()
                    .value
                
                // Konvertuj u Workout strukturu
                var result: [Workout] = []
                for workoutData in workoutsData {
                    // Učitaj exercises
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
                        isCompleted: workoutData.is_completed ?? true, // Svi su završeni
                        notes: workoutData.notes,
                        duration: workoutData.duration
                    )
                    result.append(workout)
                }
                
                completion(result)
            } catch {
                print("❌ Error loading workouts: \(error)")
                completion([])
            }
        }
    }
    
    func deleteWorkout(_ workout: Workout) async throws {
        struct WorkoutPlanIdOnly: Codable {
            let plan_id: String
        }
        
        // Pronađi plan_id za ovaj workout
        let workoutsResponse: [WorkoutPlanIdOnly] = try await supabase
            .from("workouts")
            .select("plan_id")
            .eq("workout_id", value: workout.id)
            .execute()
            .value
        
        guard let planId = workoutsResponse.first?.plan_id else {
            throw NSError(domain: "WorkoutNotFound", code: 404)
        }
        
        // Obriši exercises prvo
        try await supabase
            .from("exercises")
            .delete()
            .eq("workout_id", value: workout.id)
            .eq("plan_id", value: planId)
            .execute()
        
        // Obriši workout
        try await supabase
            .from("workouts")
            .delete()
            .eq("workout_id", value: workout.id)
            .eq("plan_id", value: planId)
            .execute()
    }
    
    // MARK: - User Meals
    
    func saveMeal(_ meal: Meal) async throws {
        // Koristi Codable strukturu umesto dictionary
        let mealData = UserMealData(
            id: meal.id,
            name: meal.name,
            time: meal.time,
            date: meal.date,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fat: meal.fat,
            notes: meal.notes
        )
        
        try await supabase
            .from("user_meals")
            .upsert(mealData)
            .execute()
        
        // Očisti prethodne food stavke za meal da update ne duplira podatke.
        try await supabase
            .from("user_food_records")
            .delete()
            .eq("meal_id", value: meal.id)
            .execute()
        
        // Sačuvaj trenutne foods
        guard !meal.foods.isEmpty else { return }
        
        let foodsData = meal.foods.map { food in
            UserFoodData(
                id: UUID().uuidString,
                meal_id: meal.id,
                name: food.name,
                quantity: food.quantity,
                calories: food.calories,
                protein: food.protein,
                carbs: food.carbs,
                fat: food.fat
            )
        }
        
        try await supabase
            .from("user_food_records")
            .insert(foodsData)
            .execute()
    }
    
    func listenToMeals(completion: @escaping ([Meal]) -> Void) {
        // Pojednostavljeni pristup - učitaj podatke odmah
        Task {
            do {
                // Učitaj sve meals
                let mealsData: [UserMealData] = try await supabase
                    .from("user_meals")
                    .select()
                    .order("date", ascending: false)
                    .execute()
                    .value
                
                // Konvertuj u Meal strukturu
                var result: [Meal] = []
                for mealData in mealsData {
                    // Učitaj foods
                    let foodsData: [UserFoodData] = try await supabase
                        .from("user_food_records")
                        .select()
                        .eq("meal_id", value: mealData.id)
                        .execute()
                        .value
                    
                    let foods = foodsData.map { foodData in
                        Meal.FoodItem(
                            id: foodData.id,
                            name: foodData.name,
                            quantity: foodData.quantity,
                            calories: foodData.calories,
                            protein: foodData.protein,
                            carbs: foodData.carbs,
                            fat: foodData.fat
                        )
                    }
                    
                    let meal = Meal(
                        id: mealData.id,
                        name: mealData.name,
                        time: mealData.time,
                        foods: foods,
                        calories: mealData.calories,
                        protein: mealData.protein,
                        carbs: mealData.carbs,
                        fat: mealData.fat,
                        date: mealData.date,
                        notes: mealData.notes
                    )
                    result.append(meal)
                }
                
                completion(result)
            } catch {
                print("❌ Error loading meals: \(error)")
                completion([])
            }
        }
    }
    
    func deleteMeal(_ meal: Meal) async throws {
        try await supabase
            .from("user_food_records")
            .delete()
            .eq("meal_id", value: meal.id)
            .execute()
        
        try await supabase
            .from("user_meals")
            .delete()
            .eq("id", value: meal.id)
            .execute()
    }
    
    // MARK: - Body Progress
    
    func fetchBodyProgressEntries() async throws -> [BodyProgressData] {
        do {
            let rows: [BodyProgressData] = try await supabase
                .from("user_body_progress")
                .select()
                .order("date", ascending: false)
                .execute()
                .value
            return rows
        } catch {
            print("❌ Error loading body progress entries: \(error)")
            throw error
        }
    }
    
    func saveBodyProgressEntry(_ entry: BodyProgressUpsertData) async throws {
        do {
            try await supabase
                .from("user_body_progress")
                .upsert(entry)
                .execute()
        } catch {
            // Backward compatibility: if migration for comparison_json is not applied yet,
            // retry without that column so body-progress sync keeps working.
            let message = error.localizedDescription.lowercased()
            if message.contains("comparison_json") || message.contains("schema cache") {
                let legacy = BodyProgressUpsertDataLegacy(
                    id: entry.id,
                    date: entry.date,
                    weight: entry.weight,
                    waist: entry.waist,
                    chest: entry.chest,
                    arm: entry.arm,
                    photo_path: entry.photo_path,
                    photo_base64: entry.photo_base64,
                    analysis_json: entry.analysis_json
                )
                try await supabase
                    .from("user_body_progress")
                    .upsert(legacy)
                    .execute()
                return
            }
            
            print("❌ Error saving body progress entry: \(error)")
            throw error
        }
    }
    
    func deleteBodyProgressEntry(id: String) async throws {
        do {
            try await supabase
                .from("user_body_progress")
                .delete()
                .eq("id", value: id)
                .execute()
        } catch {
            print("❌ Error deleting body progress entry: \(error)")
            throw error
        }
    }
    
    func uploadBodyProgressPhoto(data: Data, entryId: String) async throws -> String {
        let path = "\(entryId).jpg"
        do {
            try await supabase.storage
                .from(bodyProgressBucket)
                .upload(
                    path,
                    data: data,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )
            return path
        } catch {
            print("❌ Error uploading body progress photo: \(error)")
            throw error
        }
    }
    
    func downloadBodyProgressPhoto(path: String) async throws -> Data {
        do {
            return try await supabase.storage
                .from(bodyProgressBucket)
                .download(path: path)
        } catch {
            print("❌ Error downloading body progress photo: \(error)")
            throw error
        }
    }
    
    func deleteBodyProgressPhoto(path: String) async {
        do {
            _ = try await supabase.storage
                .from(bodyProgressBucket)
                .remove(paths: [path])
        } catch {
            print("⚠️ Error deleting body progress photo from storage: \(error)")
        }
    }
}

// MARK: - Helper Types za Supabase Response

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

struct UserWorkoutData: Codable {
    let id: String
    let name: String
    let date: Date
    let is_completed: Bool
    let duration: Int?
    let notes: String?
}

struct UserExerciseData: Codable {
    let id: String
    let workout_id: String
    let name: String
    let sets: Int?
    let reps: Int?
    let weight: Double?
    let duration: Int?
    let notes: String?
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

struct BodyProgressUpsertDataLegacy: Codable {
    let id: String
    let date: Date
    let weight: Double?
    let waist: Double?
    let chest: Double?
    let arm: Double?
    let photo_path: String?
    let photo_base64: String?
    let analysis_json: String?
}
