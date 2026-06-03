import SwiftUI

@main
struct TraningPlan2026App: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .task {
          NotificationService.shared.configureDailyCheckInNotification()
        }
    }
  }
}
