import Foundation
import Combine
import Supabase

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var totalWorkouts = 0
    @Published var totalMeals = 0
    @Published var streakDays = 0
    @Published var daysActive = 0
    @Published var isLoading = false
    
    private let supabase = SupabaseConfig.shared.supabase
    private let userId: String
    
    init(userId: String) {
        self.userId = userId
    }
    
    func loadStats() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            struct Item: Codable {
                let id: String
            }
            
            let workouts: [Item] = try await supabase
                .from("user_workouts")
                .select("id")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let meals: [Item] = try await supabase
                .from("user_meals")
                .select("id")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            totalWorkouts = workouts.count
            totalMeals = meals.count
            streakDays = 0
            daysActive = 0
        } catch {
            print("Profile stats error: \(error)")
        }
    }
}
