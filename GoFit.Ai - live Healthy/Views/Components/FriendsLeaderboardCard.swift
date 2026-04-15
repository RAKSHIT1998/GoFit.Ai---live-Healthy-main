import SwiftUI

// MARK: - Friends Leaderboard Card
/// Compact leaderboard card for the home dashboard.
/// Shows friends ranking by XP for the selected period.
///
/// `period` is currently controlled by SocialHubView's picker to display
/// daily or monthly leaderboard state.
struct FriendsLeaderboardCard: View {
    let period: String
    @Environment(\.scenePhase) private var scenePhase

        private func friendBubble(entry: LeaderboardEntry) -> some View {
            VStack(spacing: 4) {
                Circle()
                    .fill(
                        entry.isCurrentUser ?
                            LinearGradient(
                                colors: [Design.Colors.primary.opacity(0.3), Design.Colors.primary.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 46, height: 46)
                    .overlay(
                        Text(String(entry.username.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    )
                Text(entry.isCurrentUser ? "You" : entry.username)
                    .font(Design.Typography.caption2)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
    @StateObject private var gamService = GamificationService()
    @State private var entries: [LeaderboardEntry] = []
    @State private var currentUserRank: Int = 0
    @State private var isLoading = true
    @State private var showFullBoard = false
    private let refreshTimer = Timer.publish(every: 45, on: .main, in: .common).autoconnect()
    
    var trophyIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.yellow, Color.orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
            Image(systemName: "trophy.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    trophyIcon
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Leaderboard")
                            .font(Design.Typography.headline)
                        Text(period)
                            .font(Design.Typography.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if currentUserRank > 0 {
                    HStack(spacing: 4) {
                        Text("You're")
                            .font(Design.Typography.caption2)
                            .foregroundColor(.secondary)
                        Text("#\(currentUserRank)")
                            .font(Design.Typography.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(rankColor(currentUserRank))
                    }
                }
            }
            
            if !entries.isEmpty {
                // Friend bubbles with current leaderboard users
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(entries.prefix(10)) { entry in
                            friendBubble(entry: entry)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, 8)
            }

            if isLoading {
                // Skeleton loading
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.12))
                                .frame(width: 22, height: 16)
                            Circle()
                                .fill(Color.gray.opacity(0.12))
                                .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.12))
                                    .frame(width: CGFloat.random(in: 80...120), height: 10)
                            }
                            Spacer()
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.gray.opacity(0.12))
                                .frame(width: 50, height: 10)
                        }
                    }
                }
                .shimmer()
            } else if entries.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Text("🏆")
                        .font(.system(size: 28))
                    Text("No leaderboard yet")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                    Text("Complete workouts to climb the ranks!")
                        .font(Design.Typography.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            } else {
                // Leaderboard rows (top 5)
                VStack(spacing: 4) {
                    ForEach(Array(entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                        leaderboardRow(entry: entry, rank: index + 1)
                        
                        if index < min(entries.count, 5) - 1 {
                            Divider()
                                .padding(.leading, 38)
                        }
                    }
                }
                
                // See full leaderboard button
                if entries.count > 5 {
                    Button {
                        HapticManager.shared.lightTap()
                        showFullBoard = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("View Full Leaderboard →")
                                .font(Design.Typography.caption)
                                .foregroundColor(Design.Colors.primary)
                            Spacer()
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        .sheet(isPresented: $showFullBoard) {
            FullLeaderboardView(entries: entries, currentUserRank: currentUserRank)
        }
        .onReceive(refreshTimer) { _ in
            guard scenePhase == .active else { return }
            Task {
                await loadLeaderboard()
            }
        }
        .onReceive(WebSocketService.shared.$leaderboardRefreshRequired) { shouldRefresh in
            guard scenePhase == .active else { return }
            guard shouldRefresh else { return }
            Task {
                await loadLeaderboard()
                WebSocketService.shared.leaderboardRefreshRequired = false
            }
        }
        .task {
            await loadLeaderboard()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await loadLeaderboard()
            }
        }
        .onChange(of: period) { _, _ in
            Task {
                await loadLeaderboard()
            }
        }
    }
    
    // MARK: - Leaderboard Row
    private func leaderboardRow(entry: LeaderboardEntry, rank: Int) -> some View {
        HStack(spacing: 10) {
            // Rank badge
            ZStack {
                if rank <= 3 {
                    Circle()
                        .fill(medalColor(rank).opacity(0.15))
                        .frame(width: 26, height: 26)
                    Text(medalEmoji(rank))
                        .font(.system(size: 14))
                } else {
                    Text("\(rank)")
                        .font(Design.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(width: 26)
                }
            }
            
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        entry.isCurrentUser
                        ? Design.Colors.primary.opacity(0.15)
                        : Color.gray.opacity(0.1)
                    )
                    .frame(width: 28, height: 28)
                
                Text(String(entry.username.prefix(1)).uppercased())
                    .font(Design.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(entry.isCurrentUser ? Design.Colors.primary : .secondary)
            }
            
            // Name
            Text(entry.isCurrentUser ? "You" : entry.username)
                .font(Design.Typography.caption)
                .fontWeight(entry.isCurrentUser ? .bold : .medium)
                .foregroundColor(entry.isCurrentUser ? Design.Colors.primary : .primary)
                .lineLimit(1)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Text("\(entry.totalPoints ?? 0)")
                        .font(Design.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(rank <= 3 ? medalColor(rank) : .secondary)
                    Text("XP")
                        .font(Design.Typography.caption2)
                        .foregroundColor(.secondary)
                }

                Text("\(entry.totalWorkoutsCompleted ?? 0) wk • \(entry.totalCaloriesBurned ?? 0) cal")
                    .font(Design.Typography.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, entry.isCurrentUser ? 6 : 0)
        .background(
            entry.isCurrentUser
            ? Design.Colors.primary.opacity(0.05)
            : Color.clear
        )
        .cornerRadius(8)
    }
    
    // MARK: - Helpers
    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return Design.Colors.primary
        }
    }
    
    private func medalColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1, green: 0.84, blue: 0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.78)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .gray
        }
    }
    
    private func medalEmoji(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }
    
    // MARK: - Load Data
    private func loadLeaderboard() async {
        guard scenePhase == .active else { return }

        do {
            let scope = period.lowercased() == "monthly" ? "monthly" : "daily"
            try await gamService.getLeaderboard(scope: scope)
            
            await MainActor.run {
                entries = gamService.leaderboard
                if let me = entries.firstIndex(where: { $0.isCurrentUser }) {
                    currentUserRank = me + 1
                } else {
                    currentUserRank = 0
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                entries = []
                currentUserRank = 0
                isLoading = false
            }
        }
    }
}

// MARK: - Full Leaderboard Sheet
struct FullLeaderboardView: View {
    let entries: [LeaderboardEntry]
    let currentUserRank: Int
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 2) {
                    // Podium
                    if entries.count >= 3 {
                        podiumView
                            .padding(.bottom, 12)
                    }
                    
                    // Full list
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        fullRow(entry: entry, rank: index + 1)
                    }
                }
                .padding()
            }
            .background(Design.Colors.background)
            .navigationTitle("Leaderboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var podiumView: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if entries.count >= 2 {
                podiumSpot(entry: entries[1], rank: 2, height: 70)
            }
            if entries.count >= 1 {
                podiumSpot(entry: entries[0], rank: 1, height: 90)
            }
            if entries.count >= 3 {
                podiumSpot(entry: entries[2], rank: 3, height: 55)
            }
        }
        .padding(.top, 20)
    }
    
    private func podiumSpot(entry: LeaderboardEntry, rank: Int, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        entry.isCurrentUser
                        ? Design.Colors.primaryGradient
                        : LinearGradient(colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: 44, height: 44)
                
                Text(String(entry.username.prefix(1)).uppercased())
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(entry.isCurrentUser ? .white : .secondary)
            }
            
            Text(entry.isCurrentUser ? "You" : entry.username)
                .font(Design.Typography.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            Text("\(entry.totalPoints ?? 0) XP")
                .font(Design.Typography.caption2)
                .foregroundColor(.secondary)
            
            // Podium block
            RoundedRectangle(cornerRadius: 8)
                .fill(podiumColor(rank))
                .frame(height: height)
                .overlay(
                    Text(podiumMedal(rank))
                        .font(.system(size: 22))
                )
        }
        .frame(maxWidth: .infinity)
    }
    
    private func podiumColor(_ rank: Int) -> LinearGradient {
        switch rank {
        case 1:
            return LinearGradient(colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)], startPoint: .top, endPoint: .bottom)
        case 2:
            return LinearGradient(colors: [Color.gray.opacity(0.25), Color.gray.opacity(0.15)], startPoint: .top, endPoint: .bottom)
        case 3:
            return LinearGradient(colors: [Color.orange.opacity(0.25), Color.brown.opacity(0.15)], startPoint: .top, endPoint: .bottom)
        default:
            return LinearGradient(colors: [Color.gray.opacity(0.1)], startPoint: .top, endPoint: .bottom)
        }
    }
    
    private func podiumMedal(_ rank: Int) -> String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return ""
        }
    }
    
    private func fullRow(entry: LeaderboardEntry, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(Design.Typography.subheadline)
                .fontWeight(.bold)
                .foregroundColor(rank <= 3 ? .orange : .secondary)
                .frame(width: 30)
            
            ZStack {
                Circle()
                    .fill(entry.isCurrentUser ? Design.Colors.primary.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 36, height: 36)
                Text(String(entry.username.prefix(1)).uppercased())
                    .font(Design.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(entry.isCurrentUser ? Design.Colors.primary : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isCurrentUser ? "You" : entry.username)
                    .font(Design.Typography.subheadline)
                    .fontWeight(entry.isCurrentUser ? .bold : .medium)
                
                HStack(spacing: 8) {
                    Label("\(entry.badgeCount ?? 0)", systemImage: "star.fill")
                        .font(Design.Typography.caption2)
                        .foregroundColor(.orange)
                    Label("\(entry.achievementCount ?? 0)", systemImage: "medal.fill")
                        .font(Design.Typography.caption2)
                        .foregroundColor(.purple)
                }

                Text("\(entry.totalWorkoutsCompleted ?? 0) workouts • \(entry.totalMealsLogged ?? 0) meals • \(entry.totalCaloriesBurned ?? 0) cal burned")
                    .font(Design.Typography.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(entry.totalPoints ?? 0) XP")
                .font(Design.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(entry.isCurrentUser ? Design.Colors.primary : .primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            entry.isCurrentUser
            ? Design.Colors.primary.opacity(0.06)
            : Color.clear
        )
        .cornerRadius(12)
    }
}
// MARK: - Global Leaderboard Card
/// Leaderboard card that shows ALL GoFit users ranked by XP for the selected period.
/// Uses `type=global` on the backend so it is NOT filtered to the user's friends.
struct GlobalLeaderboardCard: View {
    let period: String
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var gamService = GamificationService()
    @State private var entries: [LeaderboardEntry] = []
    @State private var currentUserRank: Int = 0
    @State private var isLoading = true
    @State private var showFullBoard = false
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private func userBubble(entry: LeaderboardEntry) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(
                    entry.isCurrentUser
                        ? LinearGradient(colors: [Design.Colors.primary.opacity(0.4), Design.Colors.primary.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.orange.opacity(0.4), Color.yellow.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 46, height: 46)
                .overlay(
                    Text(String(entry.username.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                )
            Text(entry.isCurrentUser ? "You" : entry.username)
                .font(Design.Typography.caption2)
                .lineLimit(1)
        }
        .frame(width: 64)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.orange, Color.yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 32, height: 32)
                        Image(systemName: "globe")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Global Board")
                            .font(Design.Typography.headline)
                        Text(period)
                            .font(Design.Typography.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if currentUserRank > 0 {
                    HStack(spacing: 4) {
                        Text("You're")
                            .font(Design.Typography.caption2)
                            .foregroundColor(.secondary)
                        Text("#\(currentUserRank)")
                            .font(Design.Typography.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(rankColor(currentUserRank))
                    }
                }
            }

            if !entries.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(entries.prefix(10)) { entry in userBubble(entry: entry) }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.bottom, 8)
            }

            if isLoading {
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.12)).frame(width: 22, height: 16)
                            Circle().fill(Color.gray.opacity(0.12)).frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 3) {
                                RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.12)).frame(width: 100, height: 10)
                            }
                            Spacer()
                            RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.12)).frame(width: 50, height: 10)
                        }
                    }
                }
                .shimmer()
            } else if entries.isEmpty {
                VStack(spacing: 8) {
                    Text("🌍").font(.system(size: 28))
                    Text("No global data yet").font(Design.Typography.caption).foregroundColor(.secondary)
                    Text("Complete workouts to climb the global ranks!").font(Design.Typography.caption2).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(entries.prefix(5).enumerated()), id: \.element.id) { index, entry in
                        globalLeaderboardRow(entry: entry, rank: index + 1)
                        if index < min(entries.count, 5) - 1 { Divider().padding(.leading, 38) }
                    }
                }
                if entries.count > 5 {
                    Button {
                        HapticManager.shared.lightTap()
                        showFullBoard = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("View Full Global Board →")
                                .font(Design.Typography.caption)
                                .foregroundColor(Design.Colors.primary)
                            Spacer()
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        .sheet(isPresented: $showFullBoard) {
            FullLeaderboardView(entries: entries, currentUserRank: currentUserRank)
        }
        .onReceive(refreshTimer) { _ in
            guard scenePhase == .active else { return }
            Task { await loadLeaderboard() }
        }
        .onReceive(WebSocketService.shared.$leaderboardRefreshRequired) { shouldRefresh in
            guard scenePhase == .active else { return }
            guard shouldRefresh else { return }
            Task {
                await loadLeaderboard()
                WebSocketService.shared.leaderboardRefreshRequired = false
            }
        }
        .task { await loadLeaderboard() }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await loadLeaderboard() }
        }
        .onChange(of: period) { _, _ in Task { await loadLeaderboard() } }
    }

    private func globalLeaderboardRow(entry: LeaderboardEntry, rank: Int) -> some View {
        HStack(spacing: 10) {
            ZStack {
                if rank <= 3 {
                    Circle().fill(medalColor(rank).opacity(0.15)).frame(width: 26, height: 26)
                    Text(medalEmoji(rank)).font(.system(size: 14))
                } else {
                    Text("\(rank)").font(Design.Typography.caption).fontWeight(.bold).foregroundColor(.secondary).frame(width: 26)
                }
            }
            ZStack {
                Circle().fill(entry.isCurrentUser ? Design.Colors.primary.opacity(0.15) : Color.gray.opacity(0.1)).frame(width: 28, height: 28)
                Text(String(entry.username.prefix(1)).uppercased())
                    .font(Design.Typography.caption).fontWeight(.bold)
                    .foregroundColor(entry.isCurrentUser ? Design.Colors.primary : .secondary)
            }
            Text(entry.isCurrentUser ? "You" : entry.username)
                .font(Design.Typography.caption)
                .fontWeight(entry.isCurrentUser ? .bold : .medium)
                .foregroundColor(entry.isCurrentUser ? Design.Colors.primary : .primary)
                .lineLimit(1)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Text("\(entry.totalPoints ?? 0)").font(Design.Typography.caption).fontWeight(.semibold).foregroundColor(rank <= 3 ? medalColor(rank) : .secondary)
                    Text("XP").font(Design.Typography.caption2).foregroundColor(.secondary)
                }
                Text("\(entry.totalWorkoutsCompleted ?? 0) wk • \(entry.totalCaloriesBurned ?? 0) cal")
                    .font(Design.Typography.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, entry.isCurrentUser ? 6 : 0)
        .background(entry.isCurrentUser ? Design.Colors.primary.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank { case 1: return .yellow; case 2: return .gray; case 3: return .orange; default: return Design.Colors.primary }
    }
    private func medalColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1, green: 0.84, blue: 0)
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.78)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .gray
        }
    }
    private func medalEmoji(_ rank: Int) -> String {
        switch rank { case 1: return "🥇"; case 2: return "🥈"; case 3: return "🥉"; default: return "" }
    }

    private func loadLeaderboard() async {
        guard scenePhase == .active else { return }

        do {
            let scope = period.lowercased() == "monthly" ? "monthly" : "daily"
            try await gamService.getGlobalLeaderboard(scope: scope)
            await MainActor.run {
                entries = gamService.globalLeaderboard
                if let me = entries.firstIndex(where: { $0.isCurrentUser }) {
                    currentUserRank = me + 1
                } else {
                    currentUserRank = 0
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                entries = []
                currentUserRank = 0
                isLoading = false
            }
        }
    }
}
