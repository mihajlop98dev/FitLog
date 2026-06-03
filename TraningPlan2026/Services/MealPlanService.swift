import Foundation
import Supabase

class MealPlanService {
    private let supabase: SupabaseClient
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    func fetchMealPlans() async throws -> [MealPlan] {
        let plansResponse: [MealPlanMetadata] = try await supabase
            .from("meal_plans")
            .select()
            .execute()
            .value
        
        guard let planData = plansResponse.first else { return [] }
        
        let mealsResponse: [MealData] = try await supabase
            .from("meals")
            .select()
            .eq("plan_id", value: planData.plan_id)
            .execute()
            .value
        
        var meals: [MealPlan.MealPlanItem] = []
        for mealData in mealsResponse {
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
    }
}
