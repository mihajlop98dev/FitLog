import Foundation

struct NutritionTargets: Codable {
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    
    static let `default` = NutritionTargets(
        calories: 2500,
        protein: 180,
        carbs: 260,
        fat: 70
    )
}
