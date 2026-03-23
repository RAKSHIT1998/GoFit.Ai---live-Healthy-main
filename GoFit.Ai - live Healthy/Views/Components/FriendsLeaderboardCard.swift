import SwiftUI

// MARK: - Friends Leaderboard Card
/// Compact weekly leaderboard card for the home dashboard.
/// Uses existing GamificationService.getLeaderboard() → [LeaderboardEntry] model.
struct FriendsLeaderboardCard: View {
        private func friendBubble(entry: LeaderboardEntry) -> some View {
            VStack(spacing: 4) {
                Circle()
                    .fill(
                        entry.isCurrentUser ? Design.Colors.primary.opacity(0.3)
                            : LinearGradient(colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
                        Text("This Week")
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
            Task {
                await loadLeaderboard()
            }
        }
        .onReceive(WebSocketService.shared.$leaderboardRefreshRequired) { shouldRefresh in
            guard shouldRefresh else { return }
            Task {
                await loadLeaderboard()
                WebSocketService.shared.leaderboardRefreshRequired = false
            }
        }
        .task {
            await loadLeaderboard()
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
            
            // Points
            HStack(spacing: 3) {
                Text("\(entry.totalPoints ?? 0)")
                    .font(Design.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(rank <= 3 ? medalColor(rank) : .secondary)
                Text("XP")
                    .font(Design.Typography.caption2)
                    .foregroundColor(.secondary)
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
        do {
            try await gamService.getLeaderboard()
            
            await MainActor.run {
                entries = gamService.leaderboard
                if let me = entries.firstIndex(where: { $0.isCurrentUser }) {
                    currentUserRank = me + 1
                }
                isLoading = false
            }
        } catch {
            // Fallback sample data
            await MainActor.run {
                entries = sampleEntries()
                currentUserRank = 3
                isLoading = false
            }
        }
    }
    
    private func sampleEntries() -> [LeaderboardEntry] {
        [
            LeaderboardEntry(id: 1, username: "FitnessPro", email: "", profilePicture: nil, totalPoints: 2450, badgeCount: 8, achievementCount: 12, rank: 1, isCurrentUser: false),
            LeaderboardEntry(id: 2, username: "HealthNut99", email: "", profilePicture: nil, totalPoints: 2100, badgeCount: 6, achievementCount: 9, rank: 2, isCurrentUser: false),
            LeaderboardEntry(id: 3, username: "You", email: "", profilePicture: nil, totalPoints: 1850, badgeCount: 5, achievementCount: 7, rank: 3, isCurrentUser: true),
            LeaderboardEntry(id: 4, username: "RunnerGal", email: "", profilePicture: nil, totalPoints: 1600, badgeCount: 4, achievementCount: 5, rank: 4, isCurrentUser: false),
            LeaderboardEntry(id: 5, username: "GymRat42", email: "", profilePicture: nil, totalPoints: 1200, badgeCount: 3, achievementCount: 4, rank: 5, isCurrentUser: false),
        ]
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
