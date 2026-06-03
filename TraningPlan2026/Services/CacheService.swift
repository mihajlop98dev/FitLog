//
//  CacheService.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import Foundation

class CacheService {
    static let shared = CacheService()
    
    private let userDefaults = UserDefaults.standard
    private let workoutPlanKey = "cached_workout_plan"
    private let mealPlanKey = "cached_meal_plan"
    private let workoutsKey = "cached_workouts"
    private let mealsKey = "cached_meals"
    
    // In-memory cache
    private var inMemoryWorkoutPlan: WorkoutPlan?
    private var inMemoryMealPlan: MealPlan?
    private var inMemoryWorkouts: [Workout] = []
    private var inMemoryMeals: [Meal] = []
    
    // MARK: - Workout Plan Cache
    
    func saveWorkoutPlan(_ plan: WorkoutPlan) {
        // Sačuvaj u memoriji
        inMemoryWorkoutPlan = plan
        
        // Sačuvaj u UserDefaults
        if let encoded = try? JSONEncoder().encode(plan) {
            userDefaults.set(encoded, forKey: workoutPlanKey)
            userDefaults.set(Date(), forKey: "\(workoutPlanKey)_timestamp")
        }
    }
    
    func getWorkoutPlan() -> WorkoutPlan? {
        // Prvo proveri in-memory cache
        if let cached = inMemoryWorkoutPlan {
            return cached
        }
        
        // Zatim proveri UserDefaults
        if let data = userDefaults.data(forKey: workoutPlanKey),
           let plan = try? JSONDecoder().decode(WorkoutPlan.self, from: data) {
            // Vrati cache odmah (stale-while-revalidate pristup)
            inMemoryWorkoutPlan = plan
            return plan
        }
        
        return nil
    }
    
    func clearWorkoutPlanCache() {
        inMemoryWorkoutPlan = nil
        userDefaults.removeObject(forKey: workoutPlanKey)
        userDefaults.removeObject(forKey: "\(workoutPlanKey)_timestamp")
    }
    
    // MARK: - Meal Plan Cache
    
    func saveMealPlan(_ plan: MealPlan) {
        // Sačuvaj u memoriji
        inMemoryMealPlan = plan
        
        // Sačuvaj u UserDefaults
        if let encoded = try? JSONEncoder().encode(plan) {
            userDefaults.set(encoded, forKey: mealPlanKey)
            userDefaults.set(Date(), forKey: "\(mealPlanKey)_timestamp")
        }
    }
    
    func getMealPlan() -> MealPlan? {
        // Prvo proveri in-memory cache
        if let cached = inMemoryMealPlan {
            return cached
        }
        
        // Zatim proveri UserDefaults
        if let data = userDefaults.data(forKey: mealPlanKey),
           let plan = try? JSONDecoder().decode(MealPlan.self, from: data) {
            // Vrati cache odmah (stale-while-revalidate pristup)
            inMemoryMealPlan = plan
            return plan
        }
        
        return nil
    }
    
    func clearMealPlanCache() {
        inMemoryMealPlan = nil
        userDefaults.removeObject(forKey: mealPlanKey)
        userDefaults.removeObject(forKey: "\(mealPlanKey)_timestamp")
    }
    
    // MARK: - Workouts Cache
    
    func saveWorkouts(_ workouts: [Workout]) {
        inMemoryWorkouts = workouts
        if let encoded = try? JSONEncoder().encode(workouts) {
            userDefaults.set(encoded, forKey: workoutsKey)
        }
    }
    
    func getWorkouts() -> [Workout]? {
        if !inMemoryWorkouts.isEmpty {
            return inMemoryWorkouts
        }
        
        if let data = userDefaults.data(forKey: workoutsKey),
           let decoded = try? JSONDecoder().decode([Workout].self, from: data) {
            inMemoryWorkouts = decoded
            return decoded
        }
        
        return nil
    }
    
    func clearWorkoutsCache() {
        inMemoryWorkouts = []
        userDefaults.removeObject(forKey: workoutsKey)
    }
    
    // MARK: - Meals Cache
    
    func saveMeals(_ meals: [Meal]) {
        inMemoryMeals = meals
        if let encoded = try? JSONEncoder().encode(meals) {
            userDefaults.set(encoded, forKey: mealsKey)
        }
    }
    
    func getMeals() -> [Meal]? {
        if !inMemoryMeals.isEmpty {
            return inMemoryMeals
        }
        
        if let data = userDefaults.data(forKey: mealsKey),
           let decoded = try? JSONDecoder().decode([Meal].self, from: data) {
            inMemoryMeals = decoded
            return decoded
        }
        
        return nil
    }
    
    func clearMealsCache() {
        inMemoryMeals = []
        userDefaults.removeObject(forKey: mealsKey)
    }
    
    // MARK: - Clear All Cache
    
    func clearAllCache() {
        clearWorkoutPlanCache()
        clearMealPlanCache()
        clearWorkoutsCache()
        clearMealsCache()
    }
}
