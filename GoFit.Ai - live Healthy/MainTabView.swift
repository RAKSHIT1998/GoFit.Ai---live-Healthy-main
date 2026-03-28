import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var purchases: PurchaseManager
    @State private var selectedTab = 0
    @State private var previousTab = 0
    @State private var tabBounce: [Bool] = [false, false, false, false, false, false]
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeDashboardView()
                .tabItem {
                    Label("Home", systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            MealHistoryView()
                .tabItem {
                    Label("Meals", systemImage: selectedTab == 1 ? "fork.knife.circle.fill" : "fork.knife.circle")
                }
                .tag(1)

            Exercise3DLibraryView()
                .tabItem {
                    Label("3D Library", systemImage: selectedTab == 2 ? "cube.transparent.fill" : "cube.transparent")
                }
                .tag(2)

            AnalyticsDashboardView()
                .tabItem {
                    Label("Analytics", systemImage: selectedTab == 3 ? "chart.bar.fill" : "chart.bar")
                }
                .tag(3)

            ToolsView()
                .tabItem {
                    Label("Tools", systemImage: selectedTab == 4 ? "wrench.and.screwdriver.fill" : "wrench.and.screwdriver")
                }
                .tag(4)

            DeviceIntegrationView()
                .tabItem {
                    Label("Device", systemImage: selectedTab == 5 ? "applewatch" : "applewatch")
                }
                .tag(5)

            SocialHubView()
                .tabItem {
                    Label("Social", systemImage: selectedTab == 6 ? "person.2.circle.fill" : "person.2.circle")
                }
                .tag(6)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: selectedTab == 7 ? "person.circle.fill" : "person.circle")
                }
                .tag(7)
        }
        .accentColor(Design.Colors.primary)
        .background(Design.Colors.background)
        .withRewardToasts()
        .onChange(of: selectedTab) { oldValue, newValue in
            // Haptic feedback on tab switch
            HapticManager.shared.lightTap()

            withAnimation(Design.Animation.springFast) {
                previousTab = newValue
            }
        }
    }
}
