import SwiftUI

@main
struct TraningPlan2026App: App {
    var body: some Scene {
        WindowGroup {
            AuthView()
                .task {
                    NotificationService.shared.configureDailyCheckInNotification()
                }
        }
    }
}
