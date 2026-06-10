import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var purchases: PurchaseManager
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Page content — hides native tab bar
            TabView(selection: $selectedTab) {
                HomeDashboardView()
                    .tag(0)
                    .toolbar(.hidden, for: .tabBar)

                MealHistoryView()
                    .tag(1)
                    .toolbar(.hidden, for: .tabBar)

                SocialHubView()
                    .tag(2)
                    .toolbar(.hidden, for: .tabBar)

                ProfileView()
                    .tag(3)
                    .toolbar(.hidden, for: .tabBar)
            }

            FloatingTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .withRewardToasts()
    }
}

// MARK: - Floating Tab Bar

private struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.colorScheme) private var colorScheme

    private let items: [(icon: String, activeIcon: String, label: String)] = [
        ("house",              "house.fill",              "Home"),
        ("fork.knife.circle",  "fork.knife.circle.fill",  "Meals"),
        ("person.2",           "person.2.fill",           "Social"),
        ("person.circle",      "person.circle.fill",      "Profile"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { index in
                TabBarItem(
                    icon: items[index].icon,
                    activeIcon: items[index].activeIcon,
                    label: items[index].label,
                    isSelected: selectedTab == index
                ) {
                    if selectedTab != index {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    withAnimation(Design.Animation.spring) {
                        selectedTab = index
                    }
                }
            }
        }
        .padding(.horizontal, Design.Spacing.md)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(colorScheme == .dark
                    ? Color(red: 0.059, green: 0.086, blue: 0.149).opacity(0.96)
                    : Color.white.opacity(0.97))
                .shadow(color: Design.Colors.primary.opacity(colorScheme == .dark ? 0.22 : 0.10),
                        radius: 18, x: 0, y: 6)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.40 : 0.06),
                        radius: 4, x: 0, y: 2)
                .overlay(
                    Capsule()
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.07)
                                : Color.black.opacity(0.05),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, Design.Spacing.lg)
        .padding(.bottom, 12)
    }
}

private struct TabBarItem: View {
    let icon: String
    let activeIcon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? activeIcon : icon)
                    .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected
                        ? Design.Colors.primary
                        : Color.secondary.opacity(0.7))
                    .scaleEffect(isSelected ? 1.05 : 1.0)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Design.Colors.primary.opacity(isSelected ? 0.13 : 0))
                    )

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(isSelected
                        ? Design.Colors.primary
                        : Color.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(Design.Animation.spring, value: isSelected)
    }
}
