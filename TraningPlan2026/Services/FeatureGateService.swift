import Foundation
import Combine
import Supabase

@MainActor
class FeatureGateService: ObservableObject {
    @Published var profile: UserProfileData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabase = SupabaseConfig.shared.supabase
    
    var hasNutrition: Bool { profile?.has_nutrition ?? false }
    var isPro: Bool { profile?.feature_tier == "pro" }
    var userId: String? { profile?.user_id }
    var featureTier: String { profile?.feature_tier ?? "free" }
    
    var isTrialValid: Bool {
        guard !isPro else { return true }
        guard let trialEndStr = profile?.trial_end_date else { return false }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        guard let trialEnd = formatter.date(from: trialEndStr) else { return true }
        return Date() < trialEnd
    }
    
    var canGenerateWorkouts: Bool {
        isPro || isTrialValid
    }
    
    func loadProfile(userId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let profiles: [UserProfileData] = try await supabase
                .from("user_profiles")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            profile = profiles.first
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func saveProfile(_ profileData: UserProfileData) async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase
                .from("user_profiles")
                .upsert(profileData)
                .execute()
            profile = profileData
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func updateFeatureTier(_ tier: String, hasNutrition: Bool) async {
        guard let current = profile, let userId = current.user_id as? String else { return }
        do {
            try await supabase
                .from("user_profiles")
                .update(["feature_tier": tier, "has_nutrition": String(hasNutrition)])
                .eq("user_id", value: userId)
                .execute()
            let updated = UserProfileData(
                id: current.id,
                user_id: current.user_id,
                name: current.name,
                age: current.age,
                gender: current.gender,
                weight_kg: current.weight_kg,
                height_cm: current.height_cm,
                goal: current.goal,
                level: current.level,
                days_per_week: current.days_per_week,
                equipment: current.equipment,
                injuries: current.injuries,
                has_nutrition: hasNutrition,
                meals_per_day: current.meals_per_day,
                allergies: current.allergies,
                motivation: current.motivation,
                trial_end_date: current.trial_end_date,
                feature_tier: tier,
                streak_count: current.streak_count,
                last_activity_date: current.last_activity_date
            )
            profile = updated
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
