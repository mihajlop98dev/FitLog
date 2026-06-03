import Foundation

struct NutritionEstimate {
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}

enum NutritionEstimatorService {
    // Simple local estimator ("AI-like" helper) based on common foods per 100g.
    private static let nutritionPer100g: [String: NutritionEstimate] = [
        "chicken": .init(calories: 165, protein: 31, carbs: 0, fat: 3.6),
        "piletina": .init(calories: 165, protein: 31, carbs: 0, fat: 3.6),
        "rice": .init(calories: 130, protein: 2.7, carbs: 28, fat: 0.3),
        "pirinac": .init(calories: 130, protein: 2.7, carbs: 28, fat: 0.3),
        "oats": .init(calories: 389, protein: 16.9, carbs: 66.3, fat: 6.9),
        "ovsene": .init(calories: 389, protein: 16.9, carbs: 66.3, fat: 6.9),
        "egg": .init(calories: 155, protein: 13, carbs: 1.1, fat: 11),
        "jaje": .init(calories: 155, protein: 13, carbs: 1.1, fat: 11),
        "banana": .init(calories: 89, protein: 1.1, carbs: 23, fat: 0.3),
        "apple": .init(calories: 52, protein: 0.3, carbs: 14, fat: 0.2),
        "jabuka": .init(calories: 52, protein: 0.3, carbs: 14, fat: 0.2),
        "beef": .init(calories: 250, protein: 26, carbs: 0, fat: 15),
        "junetina": .init(calories: 250, protein: 26, carbs: 0, fat: 15),
        "potato": .init(calories: 77, protein: 2, carbs: 17, fat: 0.1),
        "krompir": .init(calories: 77, protein: 2, carbs: 17, fat: 0.1),
        "yogurt": .init(calories: 61, protein: 3.5, carbs: 4.7, fat: 3.3),
        "jogurt": .init(calories: 61, protein: 3.5, carbs: 4.7, fat: 3.3),
        "milk": .init(calories: 64, protein: 3.3, carbs: 4.8, fat: 3.6),
        "mleko": .init(calories: 64, protein: 3.3, carbs: 4.8, fat: 3.6)
    ]
    
    private static let defaultPieceGrams: Double = 100
    
    static func estimate(foodName: String, quantity: String?) -> NutritionEstimate? {
        let normalized = foodName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        
        let grams = extractGrams(from: quantity, foodName: normalized) ?? 100.0
        let multiplier = grams / 100.0
        
        guard let base = nutritionPer100g.first(where: { normalized.contains($0.key) })?.value else {
            return nil
        }
        
        return NutritionEstimate(
            calories: Int((Double(base.calories) * multiplier).rounded()),
            protein: base.protein * multiplier,
            carbs: base.carbs * multiplier,
            fat: base.fat * multiplier
        )
    }
    
    static func estimatedPieceGrams(for foodName: String) -> Double {
        // AI path should handle piece-based quantities ("4 kom jaja") semantically.
        // Keep local estimator fallback simple and deterministic when AI is unavailable.
        _ = foodName
        return defaultPieceGrams
    }
    
    private static func extractGrams(from quantity: String?, foodName: String) -> Double? {
        guard let quantity else { return nil }
        let lower = quantity.lowercased().replacingOccurrences(of: ",", with: ".")
        guard let number = lower.split(whereSeparator: { !"0123456789.".contains($0) }).first,
              let value = Double(number) else { return nil }
        
        if lower.contains("kg") {
            return value * 1000.0
        }
        if lower.contains("g") {
            return value
        }
        if lower.contains("ml") {
            return value // rough 1ml ~= 1g
        }
        if lower.contains("kom") || lower.contains("komad") || lower.contains("piece") {
            return value * estimatedPieceGrams(for: foodName)
        }
        return value
    }
}
