import Foundation
import Supabase

class SupabaseService {
    let workoutPlans: WorkoutPlanService
    let exerciseCatalog: ExerciseCatalogService
    let userWorkouts: UserWorkoutService
    let mealPlans: MealPlanService
    let userMeals: UserMealService
    let bodyProgress: BodyProgressService
    let trainingQueue: TrainingQueueService
    
    init() {
        let supabase = SupabaseConfig.shared.supabase
        self.workoutPlans = WorkoutPlanService(supabase: supabase)
        self.exerciseCatalog = ExerciseCatalogService(supabase: supabase)
        self.userWorkouts = UserWorkoutService(supabase: supabase)
        self.mealPlans = MealPlanService(supabase: supabase)
        self.userMeals = UserMealService(supabase: supabase)
        self.bodyProgress = BodyProgressService(supabase: supabase)
        self.trainingQueue = TrainingQueueService(supabase: supabase)
    }
}
