//
//  MealPlan.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import Foundation

struct MealPlan: Codable {
    var planId: String
    var name: String
    var meals: [MealPlanItem]
    var startDate: Date?
    var endDate: Date?
    var notes: String?
    
    struct MealPlanItem: Identifiable, Codable {
        var id: String = UUID().uuidString
        var day: Int? // Day number in the plan (optional)
        var time: String // e.g., "Breakfast", "Lunch", "Dinner", "Doručak", "Ručak", "Večera"
        var name: String // Ime obroka/recepta
        var foods: [Meal.FoodItem] // Sastojci
        var calories: Int?
        var protein: Double? // u gramima
        var carbs: Double? // u gramima
        var fat: Double? // u gramima
        var recipe: String? // Recept/priprema
        var notes: String?
    }
}
