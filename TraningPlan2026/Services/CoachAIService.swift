import Foundation

enum CoachAIService {
    private struct ChatCompletionRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        
        let model: String
        let messages: [Message]
        let temperature: Double
    }
    
    private struct ChatCompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }
            let message: Message
        }
        
        let choices: [Choice]
    }
    
    static func generateReply(
        userMessage: String,
        workoutsThisWeek: Int,
        mealsToday: Int,
        inactiveDays: Int?,
        recentMessages: [CoachChatMessage]
    ) async -> String? {
        guard let apiKey = AppSecrets.openAIAPIKey,
              let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return nil
        }
        
        let history = recentMessages
            .suffix(8)
            .map { message in
                let role = message.sender == .coach ? "coach" : "user"
                return "- \(role): \(message.text)"
            }
            .joined(separator: "\n")
        
        let inactivityText = inactiveDays.map { "\($0)" } ?? "0"
        
        let prompt = """
        Ti si lični fitnes trener i komuniciraš na srpskom.
        Ton: topao, direktan, motivacioni, bez osuđivanja.
        Odgovori kratko (maks 3 kratke rečenice), praktično i konkretno.
        
        Kontekst korisnika:
        - Treninzi ove nedelje: \(workoutsThisWeek)/4
        - Uneti obroci danas: \(mealsToday)
        - Dani bez unosa: \(inactivityText)
        
        Skorašnji chat:
        \(history.isEmpty ? "- nema prethodnih poruka" : history)
        
        Korisnik kaže:
        \(userMessage)
        
        Vrati samo tekst odgovora (bez markdown-a, bez navodnika).
        """
        
        let body = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: [
                .init(role: "system", content: "You are a supportive personal trainer assistant for chat."),
                .init(role: "user", content: prompt)
            ],
            temperature: 0.7
        )
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            
            let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            let text = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let text, !text.isEmpty else { return nil }
            return text
        } catch {
            return nil
        }
    }
    
    static func fallbackReply(for userMessage: String, inactiveDays: Int?) -> String {
        let normalized = userMessage.lowercased()
        if normalized.contains("nemam") || normalized.contains("ne mogu") || normalized.contains("umor") {
            return "Razumem te. Ajmo danas samo mini korak: 15 minuta laganog treninga ili šetnje, čisto da održimo kontinuitet."
        }
        if let inactiveDays, inactiveDays >= 2 {
            return "Video sam da si imao pauzu par dana, ali to je skroz okej. Kreni danas sa jednim kratkim treningom i vraćamo ritam."
        }
        return "Odlično što si se javio. Hajde da danas završimo jedan konkretan korak ka cilju."
    }
}
