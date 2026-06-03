//
//  HomeViewModel.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import Foundation
import Combine

@MainActor
class HomeViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService()

    func checkPlansExist() async -> Bool {
        do {
            let workoutPlans = try await supabaseService.fetchWorkoutPlans()
            let mealPlans = try await supabaseService.fetchMealPlans()
            return !workoutPlans.isEmpty && !mealPlans.isEmpty
        } catch {
            return false
        }
    }
}
