//
//  MealViewModel.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import Foundation
import Combine

@MainActor
class MealViewModel: ObservableObject {
    @Published var meals: [Meal] = []
    @Published var mealPlan: MealPlan?
    @Published var nutritionTargets: NutritionTargets = .default
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var didLoadMeals = false
    @Published private(set) var didLoadMealPlan = false
    
    var isInitialDataReady: Bool {
        didLoadMeals && didLoadMealPlan
    }
    
    private let supabaseService = SupabaseService()
    private let cacheService = CacheService.shared
    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    
    deinit { loadTask?.cancel() }
    
    init() {
        loadNutritionTargets()
        loadMeals()
        loadMealPlan()
    }
    
    func loadMeals() {
        didLoadMeals = false
        errorMessage = nil
        
        if let cachedMeals = cacheService.getMeals() {
            print("📦 Obroci učitani iz cache-a (\(cachedMeals.count))")
            meals = cachedMeals
            didLoadMeals = true
            isLoading = false
        } else {
            isLoading = true
        }
        
        supabaseService.listenToMeals { [weak self] meals in
            Task { @MainActor in
                self?.meals = meals
                self?.cacheService.saveMeals(meals)
                self?.isLoading = false
                self?.didLoadMeals = true
            }
        }
    }
    
    func loadMealPlan() {
        didLoadMealPlan = false
        // Prvo učitaj iz cache-a (brzo, odmah)
        if let cachedPlan = cacheService.getMealPlan() {
            print("📦 Meal plan učitano iz cache-a")
            mealPlan = cachedPlan
            isLoading = false
            didLoadMealPlan = true
        } else {
            isLoading = true
        }
        
        // Zatim učitaj iz Supabase u background-u (ažuriraj cache)
        loadTask = Task { [weak self] in
            guard let self else { return }
            errorMessage = nil
            
            do {
                print("📥 Učitavanje meal plana iz Supabase...")
                let plans = try await supabaseService.fetchMealPlans()
                guard !Task.isCancelled else { return }
                print("✅ Učitano \(plans.count) planova iz Supabase")
                
                if let plan = plans.first {
                    mealPlan = plan
                    // Sačuvaj u cache za brže učitavanje sledeći put
                    cacheService.saveMealPlan(plan)
                    print("✅ Meal plan '\(plan.name)' sa \(plan.meals.count) obroka")
                } else {
                    print("⚠️ Nema planova u Supabase")
                }
                isLoading = false
                didLoadMealPlan = true
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = "Failed to load meal plan: \(error.localizedDescription)"
                isLoading = false
                didLoadMealPlan = true
                print("❌ Meal plan loading error: \(error)")
            }
        }
    }
    
    func addMeal(_ meal: Meal) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.saveMeal(meal)
            loadMeals()
            loadMealPlan()
            isLoading = false
        } catch {
            errorMessage = "Failed to save meal: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func updateMeal(_ meal: Meal) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.saveMeal(meal)
            loadMeals()
            loadMealPlan()
            isLoading = false
        } catch {
            errorMessage = "Failed to update meal: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func deleteMeal(_ meal: Meal) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseService.deleteMeal(meal)
            loadMeals()
            loadMealPlan()
            isLoading = false
        } catch {
            errorMessage = "Failed to delete meal: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    func refreshAllData() {
        loadMeals()
        loadMealPlan()
        loadNutritionTargets()
    }
    
    // MARK: - Nutrition Targets & Tracking
    
    func loadNutritionTargets() {
        if let data = UserDefaults.standard.data(forKey: "nutritionTargets"),
           let decoded = try? JSONDecoder().decode(NutritionTargets.self, from: data) {
            nutritionTargets = decoded
        } else {
            nutritionTargets = .default
        }
    }
    
    func saveNutritionTargets(_ targets: NutritionTargets) {
        nutritionTargets = targets
        if let data = try? JSONEncoder().encode(targets) {
            UserDefaults.standard.set(data, forKey: "nutritionTargets")
        }
    }
    
    func meals(for day: Date) -> [Meal] {
        let calendar = Calendar.current
        return meals
            .filter { meal in
                guard let date = meal.date else { return false }
                return calendar.isDate(date, inSameDayAs: day)
            }
            .sorted { ($0.time, $0.name) < ($1.time, $1.name) }
    }
    
    func nutritionTotals(for day: Date) -> (calories: Int, protein: Double, carbs: Double, fat: Double) {
        let dayMeals = meals(for: day)
        let calories = dayMeals.compactMap(\.calories).reduce(0, +)
        let protein = dayMeals.compactMap(\.protein).reduce(0, +)
        let carbs = dayMeals.compactMap(\.carbs).reduce(0, +)
        let fat = dayMeals.compactMap(\.fat).reduce(0, +)
        return (calories, protein, carbs, fat)
    }
    
    func nutritionRemaining(for day: Date) -> (calories: Int, protein: Double, carbs: Double, fat: Double) {
        let totals = nutritionTotals(for: day)
        return (
            max(0, nutritionTargets.calories - totals.calories),
            max(0, nutritionTargets.protein - totals.protein),
            max(0, nutritionTargets.carbs - totals.carbs),
            max(0, nutritionTargets.fat - totals.fat)
        )
    }
}
