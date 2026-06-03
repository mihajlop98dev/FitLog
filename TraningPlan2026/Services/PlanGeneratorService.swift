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
        templateExercises: [String],
        templateWorkouts: [[String]] = []
    ) async -> [GeneratedWorkout] {
        guard let apiKey = AppSecrets.deepSeekAPIKey else {
            return generateFallbackPlan(profile: profile, templateExercises: templateExercises)
        }
        
        let prompt = buildPrompt(profile: profile, templateExercises: templateExercises, templateWorkouts: templateWorkouts)
        
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": """
                Ti si vrhunski fitness coach. Pravis personalizovane planove treninga.
                
                PRAVILA:
                1. Napravi TACNO [days_per_week] treninga
                2. SVAKI trening MORA da ima 5-8 vezbi
                3. Ne ponavljaj istu vezbu u razlicitim treninzima iste nedelje
                4. Prilagodi cilju korisnika
                5. Prilagodi nivou korisnika
                6. Postuj opremu koju korisnik ima
                7. Izbegavaj vezbe koje konfliktiraju sa povredama
                8. Strukturiraj treninge logicki (push/pull/legs ili gornji/donji ili full body)
                9. Imenuj svaki trening opisno na srpskom
                10. Vrati SAMO validan JSON, bez markdown-a
                """],
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
                    let workouts = response["workouts"] ?? []
                    if validateWorkouts(workouts, expectedCount: profile.days_per_week) {
                        return workouts
                    }
                }
                if let workouts = try? decoder.decode([GeneratedWorkout].self, from: contentData) {
                    if validateWorkouts(workouts, expectedCount: profile.days_per_week) {
                        return workouts
                    }
                }
            }
        } catch {
            print("DeepSeek API error: \(error)")
        }
        
        return generateFallbackPlan(profile: profile, templateExercises: templateExercises)
    }
    
    private static func validateWorkouts(_ workouts: [GeneratedWorkout], expectedCount: Int) -> Bool {
        guard workouts.count == expectedCount else { return false }
        for w in workouts {
            guard w.exercises.count >= 5 && w.exercises.count <= 8 else { return false }
        }
        return true
    }
    
    private static func buildPrompt(profile: UserProfileData, templateExercises: [String], templateWorkouts: [[String]]) -> String {
        let injuryText: String
        if let injuries = profile.injuries, !injuries.isEmpty {
            injuryText = "Izbegavaj vezbe koje opterecuju: \(injuries.joined(separator: ", "))."
        } else {
            injuryText = "Nema povreda."
        }
        
        let templateExamples: String
        if !templateWorkouts.isEmpty {
            let examples = templateWorkouts.shuffled().prefix(3).map { workout in
                "- \(workout.joined(separator: ", "))"
            }.joined(separator: "\n")
            templateExamples = "Primeri strukture iz nase baze (jedan trening = 5-8 vezbi):\n\(examples)"
        } else {
            templateExamples = ""
        }
        
        return """
        Napravi plan treninga za korisnika:
        
        Cilj: \(profile.goal)
        Nivo: \(profile.level)
        Treninga nedeljno: \(profile.days_per_week)
        Oprema: \(profile.equipment.joined(separator: ", "))
        \(injuryText)
        
        \(templateExamples)
        
        Dostupne vezbe:
        \(templateExercises.joined(separator: ", "))
        
        Vazi: SVAKI trening MORA da ima 5-8 vezbi. Ne manje od 5.
        
        Vrati JSON:
        {"workouts": [{"name": "Naziv treninga", "day": 1, "exercises": [{"name": "Naziv vezbe", "sets": 3, "reps": 10}]}]}
        """
    }
    
    private static func generateFallbackPlan(profile: UserProfileData, templateExercises: [String]) -> [GeneratedWorkout] {
        let pushExercises = templateExercises.filter { n in
            let lower = n.lowercased()
            return lower.contains("bench") || lower.contains("pres") || lower.contains("sklek") || lower.contains("triceps") || lower.contains("dips") || lower.contains("biceps") || lower.contains("curl")
        }
        let pullExercises = templateExercises.filter { n in
            let lower = n.lowercased()
            return lower.contains("pull") || lower.contains("zgib") || lower.contains("vesl") || lower.contains("face") || lower.contains("ledj")
        }
        let legsExercises = templateExercises.filter { n in
            let lower = n.lowercased()
            return lower.contains("cucanj") || lower.contains("squat") || lower.contains("leg") || lower.contains("iskor") || lower.contains("noga") || lower.contains("lunges") || lower.contains("deadlift") || lower.contains("press")
        }
        let shouldersExercises = templateExercises.filter { n in
            let lower = n.lowercased()
            return lower.contains("shoulder") || lower.contains("lateral") || lower.contains("rame") || lower.contains("arnold")
        }
        let coreExercises = templateExercises.filter { n in
            let lower = n.lowercased()
            return lower.contains("plank") || lower.contains("trbus") || lower.contains("crun") || lower.contains("core") || lower.contains("leg raise") || lower.contains("russian")
        }
        
        let all = templateExercises.isEmpty
            ? ["Bench Press", "Pull Ups", "Squat", "Shoulder Press", "Plank", "Bicep Curl", "Triceps Dip", "Leg Press", "Deadlift", "Lateral Raise", "Row", "Cable Fly", "Face Pull", "Lunges", "Calf Raise"]
            : templateExercises
        
        let push = pushExercises.isEmpty ? all.filter { _ in true } : pushExercises
        let pull = pullExercises.isEmpty ? all.filter { _ in true } : pullExercises
        let legs = legsExercises.isEmpty ? all.filter { _ in true } : legsExercises
        let shoulders = shouldersExercises.isEmpty ? all.filter { _ in true } : shouldersExercises
        let core = coreExercises.isEmpty ? all.filter { _ in true } : coreExercises
        
        let pick: ([String], Int) -> [GeneratedExercise] = { pool, count in
            pool.shuffled().prefix(count).map { name in
                GeneratedExercise(
                    name: name,
                    sets: profile.level == "pocetnik" ? 3 : (profile.level == "napredan" ? 4 : 3),
                    reps: profile.goal == "mrsavljenje" ? 12 : (profile.goal == "definicija" ? 15 : 10)
                )
            }
        }
        
        func pushWorkout(_ day: Int) -> GeneratedWorkout {
            GeneratedWorkout(name: "Gornji deo - Potisak", day: day, exercises: pick(push, 4) + pick(shoulders, 2) + pick(core, 1))
        }
        func pullWorkout(_ day: Int) -> GeneratedWorkout {
            GeneratedWorkout(name: "Gornji deo - Vucenje", day: day, exercises: pick(pull, 4) + pick(shoulders, 2) + pick(core, 1))
        }
        func legsWorkout(_ day: Int) -> GeneratedWorkout {
            GeneratedWorkout(name: "Donji deo", day: day, exercises: pick(legs, 5) + pick(core, 1))
        }
        func upperWorkout(_ day: Int) -> GeneratedWorkout {
            GeneratedWorkout(name: "Gornji deo tela", day: day, exercises: pick(push, 3) + pick(pull, 2) + pick(shoulders, 1) + pick(core, 1))
        }
        func lowerWorkout(_ day: Int) -> GeneratedWorkout {
            GeneratedWorkout(name: "Donji deo tela", day: day, exercises: pick(legs, 5) + pick(core, 2))
        }
        func fullBody(_ day: Int) -> GeneratedWorkout {
            GeneratedWorkout(name: "Pun telo", day: day, exercises: pick(push, 2) + pick(pull, 2) + pick(legs, 2) + pick(shoulders, 1) + pick(core, 1))
        }
        
        var plans: [GeneratedWorkout] = []
        let schedule: [Int: GeneratedWorkout]
        
        switch profile.days_per_week {
        case 2:
            schedule = [1: upperWorkout(1), 2: lowerWorkout(2)]
        case 3:
            schedule = [1: pushWorkout(1), 2: pullWorkout(2), 3: legsWorkout(3)]
        case 4:
            schedule = [1: upperWorkout(1), 2: lowerWorkout(2), 3: pushWorkout(3), 4: pullWorkout(4)]
        case 5:
            schedule = [1: pushWorkout(1), 2: pullWorkout(2), 3: legsWorkout(3), 4: upperWorkout(4), 5: lowerWorkout(5)]
        case 6:
            schedule = [1: pushWorkout(1), 2: pullWorkout(2), 3: legsWorkout(3), 4: upperWorkout(4), 5: lowerWorkout(5), 6: fullBody(6)]
        default:
            schedule = [1: fullBody(1)]
        }
        
        for day in 1...profile.days_per_week {
            plans.append(schedule[day] ?? fullBody(day))
        }
        
        return plans
    }
}
