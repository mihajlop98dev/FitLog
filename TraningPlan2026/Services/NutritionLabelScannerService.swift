import Foundation
import UIKit
import Vision

enum NutritionLabelScannerService {
    struct ScannedNutritionLabel {
        let estimate: NutritionEstimate
        let basisGrams: Double?
        let rawOCRText: String
    }
    
    static func scanNutrition(from image: UIImage) async -> ScannedNutritionLabel? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .sorted {
                        let y0 = $0.boundingBox.midY
                        let y1 = $1.boundingBox.midY
                        if abs(y0 - y1) > 0.02 {
                            return y0 > y1 // top to bottom
                        }
                        return $0.boundingBox.minX < $1.boundingBox.minX
                    }
                let lines = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: parseNutrition(from: lines))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["sr-RS", "en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private static func parseNutrition(from rawLines: [String]) -> ScannedNutritionLabel? {
        let lines = rawLines
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let text = lines.joined(separator: "\n")
        
        let kcal = findKcal(in: lines) ?? extractDouble(pattern: #"([0-9]+(?:[.,][0-9]+)?)\s*kcal"#, from: text)
        let protein = findValue(
            in: lines,
            labels: ["protein", "proteini"],
            excluding: ["hidrolizat"]
        )
        let carbs = findValue(
            in: lines,
            labels: ["ugljeni", "carbohydrate", "carbs", "uh "],
            excluding: ["od kojih seceri", "šećeri", "sugars"]
        )
        let fat = findValue(
            in: lines,
            labels: ["masti", "fat", "fats"],
            excluding: ["zasicene", "zasićene", "saturated"]
        )
        
        if kcal == nil && protein == nil && carbs == nil && fat == nil {
            return nil
        }
        
        let estimate = NutritionEstimate(
            calories: Int((kcal ?? 0).rounded()),
            protein: protein ?? 0,
            carbs: carbs ?? 0,
            fat: fat ?? 0
        )
        
        let basis = extractBasisGrams(from: text)
        return ScannedNutritionLabel(
            estimate: estimate,
            basisGrams: basis,
            rawOCRText: lines.joined(separator: "\n")
        )
    }
    
    private static func extractDouble(pattern: String, from text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        
        let raw = String(text[valueRange]).replacingOccurrences(of: ",", with: ".")
        return Double(raw)
    }
    
    private static func findKcal(in lines: [String]) -> Double? {
        for line in lines where line.contains("kcal") || line.contains("energ") {
            if let v = extractDouble(pattern: #"([0-9]+(?:[.,][0-9]+)?)\s*kcal"#, from: line) {
                return v
            }
            if let v = extractFirstNumber(from: line), v < 1500 {
                return v
            }
        }
        return nil
    }
    
    private static func findValue(
        in lines: [String],
        labels: [String],
        excluding: [String]
    ) -> Double? {
        for (index, line) in lines.enumerated() {
            let hasLabel = labels.contains { line.contains($0) }
            if !hasLabel { continue }
            if excluding.contains(where: { line.contains($0) }) { continue }
            
            if let value = extractFirstNumber(from: line) {
                return value
            }
            
            if index + 1 < lines.count, let nextValue = extractFirstNumber(from: lines[index + 1]) {
                return nextValue
            }
        }
        return nil
    }
    
    private static func extractFirstNumber(from line: String) -> Double? {
        extractDouble(pattern: #"([0-9]+(?:[.,][0-9]+)?)"#, from: line)
    }
    
    private static func extractBasisGrams(from text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        
        let per100Patterns = [
            #"na\s*100\s*g"#,
            #"per\s*100\s*g"#,
            #"100\s*g"#,
            #"100g"#
        ]
        for pattern in per100Patterns {
            if normalized.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return 100
            }
        }
        
        let servingPatterns = [
            #"(?:porcija|serving)[^0-9]{0,12}([0-9]+(?:\.[0-9]+)?)\s*g"#,
            #"(?:za|for)[^0-9]{0,12}([0-9]+(?:\.[0-9]+)?)\s*g"#
        ]
        for pattern in servingPatterns {
            if let grams = extractDouble(pattern: pattern, from: normalized), grams > 0 {
                return grams
            }
        }
        
        return nil
    }
}
