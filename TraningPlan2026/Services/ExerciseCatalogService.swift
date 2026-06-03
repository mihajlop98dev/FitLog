import Foundation
import Supabase

class ExerciseCatalogService {
    private let supabase: SupabaseClient
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    func fetchAllExercisesFromCatalog() async throws -> [String] {
        let response: [ExerciseCatalogItem] = try await supabase
            .from("exercise_catalog")
            .select()
            .order("name", ascending: true)
            .execute()
            .value
        return response.map { $0.name }
    }
    
    func fetchExercisesByCategory() async throws -> [String: [String]] {
        let response: [ExerciseCatalogItem] = try await supabase
            .from("exercise_catalog")
            .select()
            .order("name", ascending: true)
            .execute()
            .value
        
        var categorized: [String: [String]] = [:]
        for item in response {
            let category = item.category ?? "Ostalo"
            if categorized[category] == nil {
                categorized[category] = []
            }
            categorized[category]?.append(item.name)
        }
        return categorized
    }
    
    func fetchExerciseGuidesFromCatalog() async throws -> [String: String] {
        let response: [ExerciseCatalogItem] = try await supabase
            .from("exercise_catalog")
            .select()
            .execute()
            .value
        
        var guides: [String: String] = [:]
        for item in response {
            let guide = item.instructions ?? item.description ?? item.how_to ?? item.execution_tips ?? item.notes
            guard let guide, !guide.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            guides[item.name] = guide
        }
        return guides
    }
    
    func addExerciseToCatalog(name: String) async throws {
        let exerciseData = ExerciseCatalogData(name: name)
        try await supabase
            .from("exercise_catalog")
            .upsert(exerciseData)
            .execute()
    }
}
