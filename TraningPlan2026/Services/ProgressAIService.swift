import Foundation

enum ProgressAIService {
    private struct ChatCompletionRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: Content
        }
        
        enum Content: Encodable {
            case text(String)
            case parts([Part])
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .text(let string):
                    try container.encode(string)
                case .parts(let parts):
                    try container.encode(parts)
                }
            }
        }
        
        struct Part: Encodable {
            let type: String
            let text: String?
            let image_url: ImageURL?
            
            struct ImageURL: Encodable {
                let url: String
            }
            
            static func text(_ value: String) -> Part {
                Part(type: "text", text: value, image_url: nil)
            }
            
            static func image(_ dataURL: String) -> Part {
                Part(type: "image_url", text: nil, image_url: .init(url: dataURL))
            }
        }
        
        struct ResponseFormat: Encodable {
            let type: String
        }
        
        let model: String
        let messages: [Message]
        let temperature: Double
        let response_format: ResponseFormat
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
    
    private struct AnalysisJSON: Decodable {
        let summary: String
        let bodyFatTrend: String
        let posture: String
        let recommendations: [String]
        let confidence: Double
    }
    
    private struct ComparisonJSON: Decodable {
        let summary: String
        let visibleProgressAreas: [String]
        let noClearChangeAreas: [String]
        let measurementsSummary: String?
        let confidence: Double
    }
    
    static func analyzeProgressPhoto(
        imageData: Data,
        weight: Double?,
        waist: Double?,
        chest: Double?,
        arm: Double?
    ) async -> BodyProgressAnalysis? {
        guard let apiKey = AppSecrets.openAIAPIKey else {
            return nil
        }
        
        let base64 = imageData.base64EncodedString()
        let dataURL = "data:image/jpeg;base64,\(base64)"
        
        let metrics = """
        Težina: \(weight.map { String(format: "%.1f kg", $0) } ?? "nije uneta")
        Obim struka: \(waist.map { String(format: "%.1f cm", $0) } ?? "nije unet")
        Obim grudi: \(chest.map { String(format: "%.1f cm", $0) } ?? "nije unet")
        Obim ruke: \(arm.map { String(format: "%.1f cm", $0) } ?? "nije unet")
        """
        
        let prompt = """
        Analiziraj progres fitnes fotografije korisnika i date mere.
        Vrati isključivo JSON sa poljima:
        {
          "summary": string,
          "bodyFatTrend": string,
          "posture": string,
          "recommendations": [string, string, string],
          "confidence": double
        }
        
        Pravila:
        - Budi pažljiv i ne tvrdi medicinske dijagnoze.
        - Daj praktične i motivacione preporuke.
        - Ako je procena nesigurna, reci to kroz niži confidence.
        
        Mere:
        \(metrics)
        """
        
        let requestBody = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: [
                .init(
                    role: "system",
                    content: .text("You are a cautious fitness progress analyst. Return only valid JSON.")
                ),
                .init(
                    role: "user",
                    content: .parts([
                        .text(prompt),
                        .image(dataURL)
                    ])
                )
            ],
            temperature: 0.3,
            response_format: .init(type: "json_object")
        )
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            
            let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            guard let content = completion.choices.first?.message.content,
                  let jsonData = content.data(using: .utf8) else {
                return nil
            }
            
            let parsed = try JSONDecoder().decode(AnalysisJSON.self, from: jsonData)
            return BodyProgressAnalysis(
                summary: parsed.summary,
                bodyFatTrend: parsed.bodyFatTrend,
                posture: parsed.posture,
                recommendations: parsed.recommendations,
                confidence: min(max(parsed.confidence, 0), 1),
                disclaimer: "Ovo je informativna AI procena i ne predstavlja medicinski savet."
            )
        } catch {
            return nil
        }
    }
    
    static func compareProgressPhotos(
        previousImageData: Data,
        currentImageData: Data,
        previousDate: Date?,
        currentDate: Date?,
        previousWeight: Double?,
        currentWeight: Double?,
        previousWaist: Double?,
        currentWaist: Double?,
        previousChest: Double?,
        currentChest: Double?,
        previousArm: Double?,
        currentArm: Double?
    ) async -> BodyProgressComparisonAnalysis? {
        guard let apiKey = AppSecrets.openAIAPIKey else {
            return nil
        }
        
        let previousBase64 = previousImageData.base64EncodedString()
        let currentBase64 = currentImageData.base64EncodedString()
        let previousDataURL = "data:image/jpeg;base64,\(previousBase64)"
        let currentDataURL = "data:image/jpeg;base64,\(currentBase64)"
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sr_RS")
        formatter.dateFormat = "d. MMM yyyy"
        let previousDateText = previousDate.map { formatter.string(from: $0) } ?? "raniji unos"
        let currentDateText = currentDate.map { formatter.string(from: $0) } ?? "novi unos"
        
        let contextText = """
        Poređenje unosa:
        Prethodni datum: \(previousDateText)
        Novi datum: \(currentDateText)
        Težina: \(previousWeight.map { String(format: "%.1f", $0) } ?? "-") -> \(currentWeight.map { String(format: "%.1f", $0) } ?? "-") kg
        Struk: \(previousWaist.map { String(format: "%.1f", $0) } ?? "-") -> \(currentWaist.map { String(format: "%.1f", $0) } ?? "-") cm
        Grudi: \(previousChest.map { String(format: "%.1f", $0) } ?? "-") -> \(currentChest.map { String(format: "%.1f", $0) } ?? "-") cm
        Ruka: \(previousArm.map { String(format: "%.1f", $0) } ?? "-") -> \(currentArm.map { String(format: "%.1f", $0) } ?? "-") cm
        """
        
        let prompt = """
        Analiziraj dve fotografije tela (pre i posle) i proceni da li se vidi napredak.
        Prva slika je prethodni unos, druga slika je novi unos.
        
        Vrati isključivo JSON:
        {
          "summary": string,
          "visibleProgressAreas": [string, string],
          "noClearChangeAreas": [string, string],
          "measurementsSummary": string,
          "confidence": double
        }
        
        Pravila:
        - Ne izmišljaj detalje koje nisu jasno vidljive.
        - Ako napredak nije jasan, reci to direktno.
        - Bez medicinskih tvrdnji.
        - Obavezno uzmi u obzir promene u merama (težina, struk, grudi, ruka), ne samo slike.
        - U "measurementsSummary" ukratko objasni šta mere sugerišu.
        
        Kontekst:
        \(contextText)
        """
        
        let requestBody = ChatCompletionRequest(
            model: "gpt-4o-mini",
            messages: [
                .init(
                    role: "system",
                    content: .text("You are a careful body progress comparison assistant. Return only valid JSON.")
                ),
                .init(
                    role: "user",
                    content: .parts([
                        .text(prompt),
                        .image(previousDataURL),
                        .image(currentDataURL)
                    ])
                )
            ],
            temperature: 0.2,
            response_format: .init(type: "json_object")
        )
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            
            let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
            guard let content = completion.choices.first?.message.content,
                  let jsonData = content.data(using: .utf8) else {
                return nil
            }
            
            let parsed = try JSONDecoder().decode(ComparisonJSON.self, from: jsonData)
            return BodyProgressComparisonAnalysis(
                summary: parsed.summary,
                visibleProgressAreas: parsed.visibleProgressAreas,
                noClearChangeAreas: parsed.noClearChangeAreas,
                measurementsSummary: parsed.measurementsSummary,
                confidence: min(max(parsed.confidence, 0), 1),
                disclaimer: "AI poređenje je informativno i ne predstavlja medicinski savet."
            )
        } catch {
            return nil
        }
    }
}
