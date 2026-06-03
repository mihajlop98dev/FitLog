import Foundation
import Combine
import Supabase
import LocalAuthentication
import Security

@MainActor
class AuthService: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userId: String?
    
    private let supabase = SupabaseConfig.shared.supabase
    
    init() {
        Task { await checkExistingSession() }
    }
    
    func checkExistingSession() async {
        do {
            let session = try await supabase.auth.session
            if session.accessToken != nil {
                isAuthenticated = true
                userId = session.user.id.uuidString
            }
        } catch {
            tryBiometricLogin()
        }
    }
    
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await supabase.auth.signUp(email: email, password: password)
            userId = result.user.id.uuidString
            isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            userId = session.user.id.uuidString
            isAuthenticated = true
            saveCredentials(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func signOut() async {
        do {
            try await supabase.auth.signOut()
            clearCredentials()
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func tryBiometricLogin() {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return
        }
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Prijavi se pomoću FaceID / TouchID") { success, _ in
            if success {
                Task { @MainActor in
                    await self.autoSignInWithSavedCredentials()
                }
            }
        }
    }
    
    private func autoSignInWithSavedCredentials() async {
        guard let credentials = loadCredentials() else { return }
        do {
            try await supabase.auth.signIn(email: credentials.email, password: credentials.password)
            isAuthenticated = true
        } catch {
            clearCredentials()
        }
    }
    
    private func saveCredentials(email: String, password: String) {
        guard let service = Bundle.main.bundleIdentifier else { return }
        
        let emailData = Data(email.utf8)
        let passwordData = Data(password.utf8)
        
        let emailQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).auth.email",
            kSecAttrAccount as String: "email",
            kSecValueData as String: emailData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).auth.password",
            kSecAttrAccount as String: "password",
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(emailQuery as CFDictionary)
        SecItemDelete(passwordQuery as CFDictionary)
        SecItemAdd(emailQuery as CFDictionary, nil)
        SecItemAdd(passwordQuery as CFDictionary, nil)
    }
    
    private func loadCredentials() -> (email: String, password: String)? {
        guard let service = Bundle.main.bundleIdentifier else { return nil }
        
        let emailQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).auth.email",
            kSecAttrAccount as String: "email",
            kSecReturnData as String: true
        ]
        
        let passwordQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "\(service).auth.password",
            kSecAttrAccount as String: "password",
            kSecReturnData as String: true
        ]
        
        var emailResult: AnyObject?
        var passwordResult: AnyObject?
        
        guard SecItemCopyMatching(emailQuery as CFDictionary, &emailResult) == errSecSuccess,
              SecItemCopyMatching(passwordQuery as CFDictionary, &passwordResult) == errSecSuccess,
              let emailData = emailResult as? Data,
              let passwordData = passwordResult as? Data,
              let email = String(data: emailData, encoding: .utf8),
              let password = String(data: passwordData, encoding: .utf8) else {
            return nil
        }
        
        return (email, password)
    }
    
    private func clearCredentials() {
        guard let service = Bundle.main.bundleIdentifier else { return }
        
        [("email", "email"), ("password", "password")].forEach { _, account in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "\(service).auth.\(account)",
                kSecAttrAccount as String: account
            ]
            SecItemDelete(query as CFDictionary)
        }
    }
}
