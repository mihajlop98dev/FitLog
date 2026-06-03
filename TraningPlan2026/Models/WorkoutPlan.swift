//
//  WorkoutPlan.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import Foundation

struct WorkoutPlan: Codable {
    var planId: String
    var name: String
    var workouts: [WorkoutPlanItem]
    var startDate: Date?
    var endDate: Date?
    var notes: String?
    
    struct WorkoutPlanItem: Identifiable, Codable {
        var id: String = UUID().uuidString
        var day: Int // Day number in the plan
        var name: String
        var date: String? // ISO date string (e.g., "2026-02-23")
        var exercises: [Workout.Exercise]
        var notes: String?
        
        var workoutDate: Date? {
            guard let dateString = date else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            return formatter.date(from: dateString)
        }
    }
}
