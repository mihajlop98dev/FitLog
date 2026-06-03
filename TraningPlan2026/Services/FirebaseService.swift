//
//  FirebaseService.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import Foundation
import FirebaseFirestore

class FirebaseService {
    private let db = Firestore.firestore()
    
    // Collections
    private let workoutsCollection = "workouts"
    private let mealsCollection = "meals"
    private let workoutPlansCollection = "workoutPlans"
    private let mealPlansCollection = "mealPlans"
    
    // MARK: - Workouts
    
    func saveWorkout(_ workout: Workout) async throws {
        try await db.collection(workoutsCollection).document(workout.id).setData(from: workout)
    }
    
    func fetchWorkouts() async throws -> [Workout] {
        let snapshot = try await db.collection(workoutsCollection)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Workout.self)
        }
    }
    
    func fetchCompletedWorkouts() async throws -> [Workout] {
        let snapshot = try await db.collection(workoutsCollection)
            .whereField("isCompleted", isEqualTo: true)
            .order(by: "date", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Workout.self)
        }
    }
    
    func deleteWorkout(_ workout: Workout) async throws {
        try await db.collection(workoutsCollection).document(workout.id).delete()
    }
    
    func listenToWorkouts(completion: @escaping ([Workout]) -> Void) {
        db.collection(workoutsCollection)
            .order(by: "date", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let workouts = documents.compactMap { document -> Workout? in
                    try? document.data(as: Workout.self)
                }
                completion(workouts)
            }
    }
    
    // MARK: - Meals
    
    func saveMeal(_ meal: Meal) async throws {
        try await db.collection(mealsCollection).document(meal.id).setData(from: meal)
    }
    
    func fetchMeals() async throws -> [Meal] {
        let snapshot = try await db.collection(mealsCollection)
            .order(by: "time")
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Meal.self)
        }
    }
    
    func deleteMeal(_ meal: Meal) async throws {
        try await db.collection(mealsCollection).document(meal.id).delete()
    }
    
    func listenToMeals(completion: @escaping ([Meal]) -> Void) {
        db.collection(mealsCollection)
            .order(by: "time")
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                let meals = documents.compactMap { document -> Meal? in
                    try? document.data(as: Meal.self)
                }
                completion(meals)
            }
    }
    
    // MARK: - Workout Plans
    
    func saveWorkoutPlan(_ plan: WorkoutPlan) async throws {
        let planRef = db.collection(workoutPlansCollection).document(plan.planId)
        
        // Sačuvaj metadata plana
        let metadata: [String: Any] = [
            "planId": plan.planId,
            "name": plan.name,
            "startDate": plan.startDate as Any,
            "endDate": plan.endDate as Any,
            "notes": plan.notes as Any
        ]
        try await planRef.setData(metadata)
        
        // Sačuvaj workouts u subkolekciju
        let workoutsRef = planRef.collection("workouts")
        for workout in plan.workouts {
            let workoutRef = workoutsRef.document(workout.id)
            
            // Sačuvaj workout metadata (bez exercises liste)
            var workoutMetadata: [String: Any] = [
                "id": workout.id,
                "day": workout.day,
                "name": workout.name,
                "notes": workout.notes as Any
            ]
            
            // Dodaj datum ako postoji
            if let date = workout.date {
                workoutMetadata["date"] = date
            }
            
            try await workoutRef.setData(workoutMetadata)
            
            // Sačuvaj exercises u subkolekciju
            let exercisesRef = workoutRef.collection("exercises")
            for exercise in workout.exercises {
                try await exercisesRef.document(exercise.id).setData(from: exercise)
            }
        }
    }
    
    func fetchWorkoutPlans() async throws -> [WorkoutPlan] {
        do {
            print("🔍 Traženje workout planova u kolekciji '\(workoutPlansCollection)'...")
            let snapshot = try await db.collection(workoutPlansCollection).getDocuments()
            
            // Ako nema dokumenata, vrati praznu listu
            guard !snapshot.documents.isEmpty else {
                return []
            }
            
            var plans: [WorkoutPlan] = []
            
            for document in snapshot.documents {
                let planId = document.documentID
                let data = document.data()
                
                // Učitaj workouts iz subkolekcije (BEZ vežbi - lazy loading)
                // Koristimo batch query za brže učitavanje
                let workoutsSnapshot = try await document.reference.collection("workouts")
                    .order(by: "day", descending: true) // Sortiraj po danu (najveći prvo)
                    .getDocuments()
                var workouts: [WorkoutPlan.WorkoutPlanItem] = []
                
                for workoutDoc in workoutsSnapshot.documents {
                    let workoutData = workoutDoc.data()
                    let workoutId = workoutDoc.documentID
                    
                    // NE učitavamo vežbe ovde - učitavamo ih tek kada korisnik klikne na trening
                    // NE proveravamo count - to je dodatni zahtev koji usporava
                    
                    let workout = WorkoutPlan.WorkoutPlanItem(
                        id: workoutData["id"] as? String ?? workoutDoc.documentID,
                        day: workoutData["day"] as? Int ?? 0,
                        name: workoutData["name"] as? String ?? "Dan \(workoutData["day"] as? Int ?? 0)",
                        date: workoutData["date"] as? String,
                        exercises: [], // Prazna lista - učitavamo tek kada treba
                        notes: workoutData["notes"] as? String
                    )
                    workouts.append(workout)
                }
                
                // Sortiraj treninge po datumu (najsvežiji prvo) - ako imaju datume
                workouts.sort { workout1, workout2 in
                    guard let date1 = workout1.workoutDate, let date2 = workout2.workoutDate else {
                        return workout1.day > workout2.day // Ako nema datuma, sortiraj po danu (najveći prvo)
                    }
                    return date1 > date2 // Najsvežiji prvo
                }
                
                let plan = WorkoutPlan(
                    planId: planId,
                    name: data["name"] as? String ?? "",
                    workouts: workouts,
                    startDate: (data["startDate"] as? Timestamp)?.dateValue(),
                    endDate: (data["endDate"] as? Timestamp)?.dateValue(),
                    notes: data["notes"] as? String
                )
                plans.append(plan)
            }
            
            return plans
        } catch {
            print("❌ Error fetching workout plans: \(error)")
            throw error
        }
    }
    
    // MARK: - Lazy Loading Exercises
    
    func fetchExercisesForWorkout(planId: String, workoutId: String) async throws -> [Workout.Exercise] {
        let planRef = db.collection(workoutPlansCollection).document(planId)
        let workoutRef = planRef.collection("workouts").document(workoutId)
        let exercisesSnapshot = try await workoutRef.collection("exercises").getDocuments()
        
        var exercises: [Workout.Exercise] = []
        
        for exerciseDoc in exercisesSnapshot.documents {
            do {
                var exercise = try exerciseDoc.data(as: Workout.Exercise.self)
                // Ako exercise nema ID, koristi document ID
                if exercise.id.isEmpty || exercise.id == UUID().uuidString {
                    exercise.id = exerciseDoc.documentID
                }
                exercises.append(exercise)
            } catch {
                // Ako ne može da se dekoduje, pokušaj ručno
                let exerciseData = exerciseDoc.data()
                let exercise = Workout.Exercise(
                    id: exerciseDoc.documentID,
                    name: exerciseData["name"] as? String ?? "Unknown Exercise",
                    sets: exerciseData["sets"] as? Int,
                    reps: exerciseData["reps"] as? Int,
                    weight: exerciseData["weight"] as? Double,
                    duration: exerciseData["duration"] as? Int,
                    notes: exerciseData["notes"] as? String
                )
                exercises.append(exercise)
            }
        }
        
        return exercises
    }
    
    // MARK: - Meal Plans
    
    func saveMealPlan(_ plan: MealPlan) async throws {
        let planRef = db.collection(mealPlansCollection).document(plan.planId)
        
        // Sačuvaj metadata plana
        let metadata: [String: Any] = [
            "planId": plan.planId,
            "name": plan.name,
            "startDate": plan.startDate as Any,
            "endDate": plan.endDate as Any,
            "notes": plan.notes as Any
        ]
        try await planRef.setData(metadata)
        
        // Sačuvaj meals u subkolekciju
        let mealsRef = planRef.collection("meals")
        for meal in plan.meals {
            try await mealsRef.document(meal.id).setData(from: meal)
        }
    }
    
    func fetchMealPlans() async throws -> [MealPlan] {
        do {
            let snapshot = try await db.collection(mealPlansCollection).getDocuments()
            
            // Ako nema dokumenata, vrati praznu listu
            guard !snapshot.documents.isEmpty else {
                return []
            }
            
            var plans: [MealPlan] = []
            
            for document in snapshot.documents {
                let planId = document.documentID
                let data = document.data()
                
                // Učitaj meals iz subkolekcije
                let mealsSnapshot = try await document.reference.collection("meals").getDocuments()
                var meals: [MealPlan.MealPlanItem] = []
                
                for mealDoc in mealsSnapshot.documents {
                    do {
                        var meal = try mealDoc.data(as: MealPlan.MealPlanItem.self)
                        // Ako meal nema ID, koristi document ID
                        if meal.id.isEmpty || meal.id == UUID().uuidString {
                            meal.id = mealDoc.documentID
                        }
                        meals.append(meal)
                    } catch {
                        // Ako ne može da se dekoduje, pokušaj ručno
                        let mealData = mealDoc.data()
                        let foodsData = mealData["foods"] as? [[String: Any]] ?? []
                        let foods = foodsData.compactMap { foodDict -> Meal.FoodItem? in
                            guard let name = foodDict["name"] as? String else { return nil }
                            return Meal.FoodItem(
                                id: foodDict["id"] as? String ?? UUID().uuidString,
                                name: name,
                                quantity: foodDict["quantity"] as? String,
                                calories: foodDict["calories"] as? Int
                            )
                        }
                        
                        let meal = MealPlan.MealPlanItem(
                            id: mealDoc.documentID,
                            day: mealData["day"] as? Int,
                            time: mealData["time"] as? String ?? "Meal",
                            name: mealData["name"] as? String ?? "Unknown Meal",
                            foods: foods,
                            calories: mealData["calories"] as? Int,
                            protein: mealData["protein"] as? Double,
                            carbs: mealData["carbs"] as? Double,
                            fat: mealData["fat"] as? Double,
                            recipe: mealData["recipe"] as? String,
                            notes: mealData["notes"] as? String
                        )
                        meals.append(meal)
                    }
                }
                
                let plan = MealPlan(
                    planId: planId,
                    name: data["name"] as? String ?? "",
                    meals: meals,
                    startDate: (data["startDate"] as? Timestamp)?.dateValue(),
                    endDate: (data["endDate"] as? Timestamp)?.dateValue(),
                    notes: data["notes"] as? String
                )
                plans.append(plan)
            }
            
            return plans
        } catch {
            print("❌ Error fetching meal plans: \(error)")
            throw error
        }
    }
}
