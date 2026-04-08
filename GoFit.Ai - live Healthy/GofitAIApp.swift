//
//  GoFitAiApp.swift
//  GoFit.Ai - live Healthy
//

import SwiftUI
import SwiftData

@main
struct GoFitAiApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @AppStorage("darkModePreference") private var darkModePreference: String = "light"
    @StateObject private var webSocketService = WebSocketService.shared
    @StateObject private var adManager = AdManager.shared
    @StateObject private var runClubService = RunClubService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(colorScheme)
                .notificationBanner() // Add real-time notification banner
                .environmentObject(webSocketService)
                .environmentObject(adManager)
                .environmentObject(runClubService)
                .onAppear {
                    // Initialize AdMob
                    adManager.initialize()

                    // Initialize Watch connectivity
                    WatchSyncManager.shared.start()
                    
                    // Initialize services
                    _ = NotificationService.shared
                    _ = RetentionManager.shared
                    RetentionManager.shared.recordAppOpen()
                    
                    // Register smart notification categories & schedule
                    GoFitSmartNotifications.shared.registerCategories()
                    GoFitSmartNotifications.shared.scheduleSmartNotifications()
                    
                    // Refresh widget data
                    GoFitWidgetDataStore.shared.refresh()
                    
                    // Connect to WebSocket if authenticated
                    if let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty {
                        webSocketService.connect()
                    }
                }
                .onChange(of: webSocketService.latestFriendRequest) { oldValue, newValue in
                    if let request = newValue {
                        NotificationBannerManager.shared.show(
                            title: "New Friend Request",
                            message: request.message,
                            icon: "person.badge.plus.fill"
                        )
                    }
                }
                .onChange(of: webSocketService.latestChallenge) { oldValue, newValue in
                    if let challenge = newValue {
                        NotificationBannerManager.shared.show(
                            title: "Challenge Invitation",
                            message: "\(challenge.fromUsername) invited you to: \(challenge.challengeName)",
                            icon: "trophy.fill"
                        )
                    }
                }
                .onChange(of: webSocketService.latestAchievement) { oldValue, newValue in
                    if let achievement = newValue {
                        NotificationBannerManager.shared.show(
                            title: "🏅 Achievement Unlocked!",
                            message: "\(achievement.name): \(achievement.description)",
                            icon: "star.fill"
                        )
                    }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // Sleep tracker auto-detection
                    SleepManager.shared.handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)

                    // Show ad every time app becomes active
                    if newPhase == .active && oldPhase != .active {
                        RetentionManager.shared.recordAppOpen()
                        // Refresh widget with latest data
                        GoFitWidgetDataStore.shared.refresh()
                        
                        // Small delay to ensure app is fully loaded
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                            adManager.showAppOpenAd()
                        }
                    }
                }
                .onOpenURL { url in
                    guard url.scheme == "gofit" else { return }
                    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    if let host = components?.host, host == "runclub", let clubId = components?.path.split(separator: "/").first {
                        let trimmedClubId = String(clubId)
                        if let profile = LocalUserStore.shared.userProfile,
                           let userId = profile.userId,
                           !userId.isEmpty {
                            let username = profile.name.isEmpty ? "Runner" : profile.name
                            RunClubService.shared.joinClub(trimmedClubId, userId: userId, username: username)
                            NotificationBannerManager.shared.show(
                                title: "Joined Run Club",
                                message: "You joined club \(trimmedClubId) from link!",
                                icon: "person.3.fill"
                            )
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private var colorScheme: ColorScheme? {
        switch darkModePreference.lowercased() {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil // System default
        }
    }
}
