import Foundation

enum AppSecrets {
    static var openAIAPIKey: String? {
        if let envKey = validKey(from: ProcessInfo.processInfo.environment["OPENAI_API_KEY"]) {
            return envKey
        }
        
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           let validPlistKey = validKey(from: plistKey) {
            return validPlistKey
        }
        
        return nil
    }
    
    static var deepSeekAPIKey: String? {
        if let envKey = validKey(from: ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]) {
            return envKey
        }
        return nil
    }
    
    private static func validKey(from rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        
        if value.contains("$(") || value.hasPrefix("YOUR_") || value.lowercased().contains("replace_me") {
            return nil
        }
        
        return value
    }
}
