import Foundation
import Supabase

class BodyProgressService {
    private let supabase: SupabaseClient
    private let bucket = "body-progress-photos"
    
    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }
    
    func fetchEntries() async throws -> [BodyProgressData] {
        let rows: [BodyProgressData] = try await supabase
            .from("user_body_progress")
            .select()
            .order("date", ascending: false)
            .execute()
            .value
        return rows
    }
    
    func saveEntry(_ entry: BodyProgressUpsertData) async throws {
        do {
            try await supabase
                .from("user_body_progress")
                .upsert(entry)
                .execute()
        } catch {
            let message = error.localizedDescription.lowercased()
            if message.contains("comparison_json") || message.contains("schema cache") {
                let legacy = BodyProgressUpsertData(
                    id: entry.id,
                    date: entry.date,
                    weight: entry.weight,
                    waist: entry.waist,
                    chest: entry.chest,
                    arm: entry.arm,
                    photo_path: entry.photo_path,
                    photo_base64: entry.photo_base64,
                    analysis_json: entry.analysis_json,
                    comparison_json: nil
                )
                try await supabase
                    .from("user_body_progress")
                    .upsert(legacy)
                    .execute()
                return
            }
            throw error
        }
    }
    
    func deleteEntry(id: String) async throws {
        try await supabase
            .from("user_body_progress")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    func uploadPhoto(data: Data, entryId: String) async throws -> String {
        let path = "\(entryId).jpg"
        try await supabase.storage
            .from(bucket)
            .upload(
                path,
                data: data,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
        return path
    }
    
    func downloadPhoto(path: String) async throws -> Data {
        try await supabase.storage
            .from(bucket)
            .download(path: path)
    }
    
    func deletePhoto(path: String) async {
        _ = try? await supabase.storage
            .from(bucket)
            .remove(paths: [path])
    }
}
