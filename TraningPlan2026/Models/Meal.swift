//
//  Meal.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import Foundation

struct Meal: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var time: String // e.g., "Breakfast", "Lunch", "Dinner", or specific time
    var foods: [FoodItem]
    var calories: Int?
    var protein: Double? = nil
    var carbs: Double? = nil
    var fat: Double? = nil
    var date: Date?
    var notes: String?
    
    struct FoodItem: Identifiable, Codable {
        var id: String = UUID().uuidString
        var name: String
        var quantity: String? // e.g., "200g", "1 cup"
        var calories: Int?
        var protein: Double? = nil
        var carbs: Double? = nil
        var fat: Double? = nil
    }
}
