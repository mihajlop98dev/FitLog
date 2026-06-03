import Foundation
import Supabase

class UserMealService {
    private let supabase: SupabaseClient
    private let userId: String
    
    init(supabase: SupabaseClient, userId: String) {
        self.supabase = supabase
        self.userId = userId
    }
    
    func saveMeal(_ meal: Meal) async throws {
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
        
        try await supabase
            .from("user_food_records")
            .delete()
            .eq("meal_id", value: meal.id)
            .execute()
        
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
        Task {
            do {
                let mealsData: [UserMealData] = try await supabase
                    .from("user_meals")
                    .select()
                    .eq("user_id", value: userId)
                    .order("date", ascending: false)
                    .execute()
                    .value
                
                var result: [Meal] = []
                for mealData in mealsData {
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
}
