import Foundation

struct BodyProgressAnalysis: Codable {
    var summary: String
    var bodyFatTrend: String
    var posture: String
    var recommendations: [String]
    var confidence: Double
    var disclaimer: String
}

struct BodyProgressComparisonAnalysis: Codable {
    var summary: String
    var visibleProgressAreas: [String]
    var noClearChangeAreas: [String]
    var measurementsSummary: String?
    var confidence: Double
    var disclaimer: String
}

struct BodyProgressEntry: Identifiable, Codable {
    var id: String = UUID().uuidString
    var date: Date
    var weight: Double?
    var waist: Double?
    var chest: Double?
    var arm: Double?
    var photoFilename: String?
    var photoRemotePath: String?
    var analysis: BodyProgressAnalysis?
    var comparison: BodyProgressComparisonAnalysis?
    var createdAt: Date = Date()
}
