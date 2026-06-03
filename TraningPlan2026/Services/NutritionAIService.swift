import Foundation

enum NutritionAIService {
    private struct ChatCompletionRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        
        let model: String
        let messages: [Message]
        let temperature: Double
        let response_format: ResponseFormat
        
        struct ResponseFormat: Encodable {
            let type: String
        }
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
    
    private struct NutritionJSON: Decodable {
        let calories: Int
        let protein: Double
        let carbs: Double
        let fat: Double
    }
    
    static func estimate(foodName: String, quantity: String?) async -> NutritionEstimate? {
        guard let apiKey = AppSecrets.openAIAPIKey else {
            return nil
        }
        
        let quantityText = (quantity?.isEmpty == false) ? (quantity ?? "") : "100g"
        let userPrompt = """
        Namirnica: \(foodName)
        Količina: \(quantityText)
        
        Vrati procenu nutritivnih vrednosti kao JSON sa poljima:
        {
          "calories": int,
          "protein": double,
          "carbs": double,
          "fat": double
        }
        """
        
        let requestBody = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: [
                .init(
                    role: "system",
                    content: "You are a nutrition assistant. Return only valid JSON. Provide realistic macronutrient estimates for the specified amount of food. If quantity is piece-based (e.g. '4 kom jaja', '5 jabuka'), infer typical average piece size automatically."
                ),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.2,
            response_format: .init(type: "json_object")
        )
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            
            let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            guard let content = completion.choices.first?.message.content,
                  let jsonData = content.data(using: .utf8) else {
                return nil
            }
            
            let parsed = try JSONDecoder().decode(NutritionJSON.self, from: jsonData)
            return NutritionEstimate(
                calories: max(0, parsed.calories),
                protein: max(0, parsed.protein),
                carbs: max(0, parsed.carbs),
                fat: max(0, parsed.fat)
            )
        } catch {
            return nil
        }
    }
}
