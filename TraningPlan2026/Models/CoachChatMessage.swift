import Foundation

struct CoachChatMessage: Identifiable, Codable {
    enum Sender: String, Codable {
        case coach
        case user
    }
    
    var id: String = UUID().uuidString
    var sender: Sender
    var text: String
    var createdAt: Date = Date()
}
