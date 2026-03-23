import SwiftUI

struct RootView: View {
    @StateObject private var auth = AuthViewModel()
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var healthKit = HealthKitService.shared
    @StateObject private var streakManager = StreakManager.shared
    @EnvironmentObject var adManager: AdManager

    @AppStorage("pendingFriendInviteId") private var pendingFriendInviteId: String = ""
    @AppStorage("hasSeenFirstTimeAppTutorial") private var hasSeenFirstTimeAppTutorial: Bool = false
    
    @State private var hasCheckedSubscriptionAfterLogin = false
    @State private var hasShownInitialAd = false
    @State private var showSplash = true
    @State private var isAppReady = false
    @State private var showFirstTimeTutorial = false
    
    var body: some View {
        ZStack {
            // Main content
            Group {
                if !auth.didFinishOnboarding {
                    OnboardingScreens()
                        .environmentObject(auth)
                        .environmentObject(purchases)
                } else if !auth.isLoggedIn {
                    AuthView()
                        .environmentObject(auth)
                        .environmentObject(purchases)
                } else {
                    // User is logged in - show main app or blocking paywall
                    // Only show blocking paywall if:
                    // 1. User is logged in (not a new signup showing onboarding paywall)
                    // 2. Subscription is required (trial expired and no subscription)
                    // 3. We've already checked subscription status (avoid showing immediately after login)
                    if hasCheckedSubscriptionAfterLogin && purchases.requiresSubscription {
                        // Blocking paywall for existing users whose trial expired
                        PaywallView()
                            .environmentObject(purchases)
                            .interactiveDismissDisabled()
                    } else {
                        MainTabView()
                            .environmentObject(auth)
                            .environmentObject(purchases)
                            .environmentObject(streakManager)
                    }
                }
            }
            .opacity(showSplash ? 0 : 1)
            
            // Splash screen overlay
            if showSplash {
                SplashScreenView {
                    // On completion, hide splash
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            // Connect AdManager to PurchaseManager
            adManager.setPurchaseManager(purchases)
            
            purchases.loadProducts()
            
            // Start loading data in background
            Task {
                // Check subscription and trial status on app launch
                if auth.isLoggedIn {
                    async let subscriptionCheck: Void = {
                        await purchases.updateSubscriptionStatus()
                        await purchases.checkSubscriptionStatus()
                        await purchases.checkTrialAndSubscriptionStatus()
                        await MainActor.run {
                            hasCheckedSubscriptionAfterLogin = true
                        }
                    }()
                    
                    async let healthCheck: Void = {
                        await MainActor.run {
                            healthKit.checkAuthorizationStatus()
                        }
                        // Always try to read data - Apple may have granted read
                        // access even though we can't verify it via authorizationStatus.
                        await MainActor.run {
                            healthKit.startPeriodicSync()
                        }
                        await healthKit.readTodayData()
                        try? await healthKit.syncToBackend()
                    }()
                    
                    async let streakCheck: Void = {
                        await MainActor.run {
                            streakManager.checkAndUpdateStreak()
                        }
                    }()
                    
                    // Wait for all initial data to load
                    _ = await (subscriptionCheck, healthCheck, streakCheck)
                }
                
                // Mark app as ready
                await MainActor.run {
                    isAppReady = true
                }

                await MainActor.run {
                    evaluateTutorialPresentation()
                }
                
                // Show app open ad if user doesn't have subscription (after splash)
                if auth.isLoggedIn && !hasShownInitialAd && !purchases.hasActiveSubscription {
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // Wait for splash to finish
                    adManager.showAppOpenAd()
                    hasShownInitialAd = true
                }
            }
        }
        .onChange(of: auth.isLoggedIn) { oldValue, newValue in
            if newValue {
                // When user logs in/signs up, initialize trial and check subscription
                // Reset the flag to prevent premature paywall display
                hasCheckedSubscriptionAfterLogin = false
                hasShownInitialAd = false
                
                Task {
                    // Give paywall time to show after signup if needed
                    // Only check subscription status after a delay
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    await purchases.updateSubscriptionStatus()
                    await purchases.checkSubscriptionStatus()
                    await purchases.checkTrialAndSubscriptionStatus()
                    
                    await MainActor.run {
                        hasCheckedSubscriptionAfterLogin = true
                        evaluateTutorialPresentation()
                    }
                    
                    // Show app open ad if user doesn't have subscription
                    if !hasShownInitialAd && !purchases.hasActiveSubscription {
                        // Delay ad slightly to let app fully load
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                        adManager.showAppOpenAd()
                        hasShownInitialAd = true
                    }
                    
                    healthKit.checkAuthorizationStatus()
                    healthKit.startPeriodicSync()
                    await healthKit.readTodayData()
                    try? await healthKit.syncToBackend()
                }

                if !pendingFriendInviteId.isEmpty {
                    FriendsService.shared.sendFriendRequest(to: pendingFriendInviteId) { _ in
                        pendingFriendInviteId = ""
                    }
                }
            } else {
                // When user logs out, stop HealthKit sync and reset flag
                hasCheckedSubscriptionAfterLogin = false
                hasShownInitialAd = false
                healthKit.stopPeriodicSync()
            }
        }
        .onChange(of: showSplash) { _ in
            evaluateTutorialPresentation()
        }
        .onChange(of: purchases.requiresSubscription) { _ in
            evaluateTutorialPresentation()
        }
        .fullScreenCover(isPresented: $showFirstTimeTutorial) {
            FirstTimeTutorialView {
                hasSeenFirstTimeAppTutorial = true
                showFirstTimeTutorial = false
            }
        }
        .onChange(of: purchases.subscriptionStatus) { oldValue, newValue in
            // Bugfix: When subscription status changes (e.g., after purchase), immediately
            // update requiresSubscription/showPaywall to dismiss blocking paywall.
            // This is safe because checkTrialAndSubscriptionStatus() no longer calls
            // updateSubscriptionStatus()/checkSubscriptionStatus(), so no infinite loop.
            if auth.isLoggedIn && oldValue != newValue {
                Task {
                    await purchases.checkTrialAndSubscriptionStatus()
                }
            }
        }
        .onOpenURL { url in
            handleInviteURL(url)
        }
    }

    private func evaluateTutorialPresentation() {
        let canShowMainContent = auth.isLoggedIn && hasCheckedSubscriptionAfterLogin && !purchases.requiresSubscription
        let shouldShow = auth.didFinishOnboarding
            && canShowMainContent
            && isAppReady
            && !showSplash
            && !hasSeenFirstTimeAppTutorial

        if shouldShow && !showFirstTimeTutorial {
            showFirstTimeTutorial = true
        }
    }

    private func handleInviteURL(_ url: URL) {
        let scheme = url.scheme?.lowercased()
        let host = url.host?.lowercased()
        let path = url.path.lowercased()

        let isCustomScheme = (scheme == "gofitai" && host == "invite")
        let isUniversalLink = (scheme == "https" && host == "gofit-ai-live-healthy-1.onrender.com" && (path == "/invite" || path == "/i"))

        guard isCustomScheme || isUniversalLink else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        
        // Try query parameter first: ?from=userId
        var inviterId = components?.queryItems?.first(where: { $0.name == "from" })?.value
        
        // Also try path-based: gofitai://invite/userId
        if inviterId == nil || inviterId?.isEmpty == true {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if !pathComponents.isEmpty {
                inviterId = pathComponents.last
            }
        }

        guard let inviterId = inviterId, !inviterId.isEmpty else { return }
        
        // Don't send friend request to yourself
        guard inviterId != auth.userId else { return }

        if auth.isLoggedIn {
            FriendsService.shared.sendFriendRequest(to: inviterId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let message):
                        print("✅ Friend invite accepted: \(message)")
                    case .failure(let error):
                        print("❌ Friend invite error: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            pendingFriendInviteId = inviterId
        }
    }
}
