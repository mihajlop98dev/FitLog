//
//  Workout.swift
//  TraningPlan2026
//
//  Created by Mihajlo Petrovic on 24. 2. 2026..
//

import Foundation

struct Workout: Identifiable, Codable {
    var id: String = UUID().uuidString
    var name: String
    var date: Date
    var exercises: [Exercise]
    var isCompleted: Bool
    var notes: String?
    var duration: Int? // in minutes
    
    struct Exercise: Identifiable, Codable {
        var id: String = UUID().uuidString
        var name: String
        var sets: Int?
        var reps: Int?
        var weight: Double? // in kg
        var duration: Int? // in seconds
        var notes: String?
        
        enum CodingKeys: String, CodingKey {
            case id, name, sets, reps, weight, duration, notes
        }
        
        init(id: String = UUID().uuidString, name: String, sets: Int? = nil, reps: Int? = nil, weight: Double? = nil, duration: Int? = nil, notes: String? = nil) {
            self.id = id.isEmpty ? UUID().uuidString : id
            self.name = name
            self.sets = sets
            self.reps = reps
            self.weight = weight
            self.duration = duration
            self.notes = notes
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // ID može biti null ili nedostajati
            if let idValue = try? container.decode(String.self, forKey: .id), !idValue.isEmpty {
                id = idValue
            } else {
                id = UUID().uuidString
            }
            
            name = try container.decode(String.self, forKey: .name)
            sets = try container.decodeIfPresent(Int.self, forKey: .sets)
            reps = try container.decodeIfPresent(Int.self, forKey: .reps)
            weight = try container.decodeIfPresent(Double.self, forKey: .weight)
            duration = try container.decodeIfPresent(Int.self, forKey: .duration)
            notes = try container.decodeIfPresent(String.self, forKey: .notes)
        }
    }
}
