#if os(watchOS)
import SwiftUI
import UserNotifications

@main
struct GoFitWatchApp: App {
    
    init() {
        // Request notification permission on watch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted { print("✅ Watch notifications authorized") }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            WatchTabView()
        }
    }
}

// MARK: - Tab Navigation
struct WatchTabView: View {
    var body: some View {
        TabView {
            WatchDashboardView()
            WatchWaterView()
            WatchQuickLogView()
        }
        .tabViewStyle(.verticalPage)
    }
}
#endif
