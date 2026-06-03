import Foundation

struct GeneratedWorkout: Codable {
    let name: String
    let day: Int
    let exercises: [GeneratedExercise]
}

struct GeneratedExercise: Codable {
    let name: String
    let sets: Int
    let reps: Int
}

class PlanGeneratorService {
    static func generatePlan(
        profile: UserProfileData,
        templateExercises: [String]
    ) async -> [GeneratedWorkout] {
        guard let apiKey = AppSecrets.deepSeekAPIKey else {
            print("DeepSeek API key not configured")
            return generateFallbackPlan(profile: profile, templateExercises: templateExercises)
        }
        
        let prompt = buildPrompt(profile: profile, templateExercises: templateExercises)
        
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": "You are a fitness coach. Create a personalized workout plan in Serbian language. Return ONLY valid JSON array, no markdown."],
                ["role": "user", "content": prompt]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.7
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            if let choices = json?["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String,
               let contentData = content.data(using: .utf8) {
                let decoder = JSONDecoder()
                if let response = try? decoder.decode([String: [GeneratedWorkout]].self, from: contentData) {
                    return response["workouts"] ?? []
                }
                if let workouts = try? decoder.decode([GeneratedWorkout].self, from: contentData) {
                    return workouts
                }
            }
        } catch {
            print("DeepSeek API error: \(error)")
        }
        
        return generateFallbackPlan(profile: profile, templateExercises: templateExercises)
    }
    
    private static func buildPrompt(profile: UserProfileData, templateExercises: [String]) -> String {
        let injuryText: String
        if let injuries = profile.injuries, !injuries.isEmpty {
            injuryText = "Izbegavaj vezbe koje opterecuju: \(injuries.joined(separator: ", "))."
        } else {
            injuryText = "Nema povreda."
        }
        
        let nutritionText = profile.has_nutrition ? "Korisnik zeli i plan ishrane." : "Bez plana ishrane."
        
        return """
        Napravi plan treninga za korisnika sa sledecim profilom:
        
        Cilj: \(profile.goal)
        Nivo: \(profile.level)
        Treninga nedeljno: \(profile.days_per_week)
        Oprema: \(profile.equipment.joined(separator: ", "))
        \(injuryText)
        \(nutritionText)
        
        Dostupne vezbe iz kataloga (izaberi 5-8 po treningu odgovarajuce):
        \(templateExercises.joined(separator: ", "))
        
        Vrati JSON u formatu:
        {"workouts": [{"name": "Naziv treninga", "day": 1, "exercises": [{"name": "Naziv vezbe", "sets": 3, "reps": 10}]}]}
        
        Ukupno \(profile.days_per_week) treninga. Prilagodi broj serija i ponavljanja nivou (\(profile.level)).
        """
    }
    
    private static func generateFallbackPlan(profile: UserProfileData, templateExercises: [String]) -> [GeneratedWorkout] {
        let workoutNames = ["Gornji deo tela", "Donji deo tela", "Gornji + kardio", "Donji + core", "Pun telo", "Gornji deo", "Donji deo"]
        var plans: [GeneratedWorkout] = []
        
        let exercises = templateExercises.isEmpty
            ? ["Sklekovi", "Cucnjevi", "Zgibovi", "Iskoraci", "Plank", "Trbusnjaci", "Propadanja"]
            : templateExercises.shuffled()
        
        let count = max(exercises.count, 1)
        
        for day in 1...profile.days_per_week {
            let startIdx = ((day - 1) * 6) % count
            let endIdx = min(startIdx + 6, count)
            let dayExercises = Array(exercises[startIdx..<endIdx])
            
            let exercises = dayExercises.map { name in
                GeneratedExercise(
                    name: name,
                    sets: profile.level == "pocetnik" ? 3 : (profile.level == "napredan" ? 4 : 3),
                    reps: profile.level == "pocetnik" ? 10 : (profile.level == "napredan" ? 12 : 10)
                )
            }
            
            plans.append(GeneratedWorkout(
                name: workoutNames[(day - 1) % workoutNames.count],
                day: day,
                exercises: exercises
            ))
        }
        
        return plans
    }
}
