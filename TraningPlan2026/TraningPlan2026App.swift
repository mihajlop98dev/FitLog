import SwiftUI

@main
struct TraningPlan2026App: App {
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            AuthView(authService: authService)
                .task {
                    NotificationService.shared.configureDailyCheckInNotification()
                }
        }
    }
}
