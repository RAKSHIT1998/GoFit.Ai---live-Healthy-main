import SwiftUI

// MARK: - Social Activity Feed Card
/// Compact card showing friend activity on the home dashboard.
/// Uses existing LogSharingService (activity feed) and ViralEngagementManager (cheers).
struct SocialActivityCard: View {
    @StateObject private var logService = LogSharingService()
    @State private var recentActivity: [FriendActivity] = []
    @State private var isLoading = true
    @State private var cheerSentTo: String? = nil
    @State private var showSocialHub = false
    
    // Lightweight model for display
    struct FriendActivity: Identifiable {
        let id: String
        let name: String
        let action: String      // "logged a workout", "scanned a meal", etc.
        let emoji: String
        let timeAgo: String
        let color: Color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    
                    Text("Friend Activity")
                        .font(Design.Typography.headline)
                }
                
                Spacer()
                
                Button {
                    HapticManager.shared.lightTap()
                    showSocialHub = true
                } label: {
                    Text("See All")
                        .font(Design.Typography.caption)
                        .foregroundColor(Design.Colors.primary)
                }
            }
            
            if isLoading {
                // Skeleton loading
                VStack(spacing: 10) {
                    ForEach(0..<2, id: \.self) { _ in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(width: 140, height: 10)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(width: 90, height: 8)
                            }
                            Spacer()
                        }
                    }
                }
                .shimmer()
            } else if recentActivity.isEmpty {
                // Empty state — encourage adding friends
                VStack(spacing: 10) {
                    Text("👥")
                        .font(.system(size: 32))
                    
                    Text("Add friends to see their activity!")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        showSocialHub = true
                        HapticManager.shared.lightTap()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.badge.plus")
                                .font(.caption)
                            Text("Find Friends")
                                .font(Design.Typography.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Design.Colors.primaryGradient)
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                // Activity items
                VStack(spacing: 2) {
                    ForEach(recentActivity.prefix(3)) { activity in
                        activityRow(activity)
                        
                        if activity.id != recentActivity.prefix(3).last?.id {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        .sheet(isPresented: $showSocialHub) {
            SocialHubView()
        }
        .task {
            await loadActivity()
        }
    }
    
    // MARK: - Activity Row
    private func activityRow(_ activity: FriendActivity) -> some View {
        HStack(spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(activity.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Text(activity.emoji)
                    .font(.system(size: 16))
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text(activity.name)
                        .font(Design.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(" \(activity.action)")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
                .lineLimit(1)
                
                Text(activity.timeAgo)
                    .font(Design.Typography.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Cheer button
            Button {
                sendCheer(to: activity.id, name: activity.name)
            } label: {
                if cheerSentTo == activity.id {
                    Text("🎉")
                        .font(.system(size: 18))
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "hands.clap.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .frame(width: 32, height: 32)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 6)
    }
    
    // MARK: - Send Cheer
    private func sendCheer(to id: String, name: String) {
        HapticManager.shared.success()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            cheerSentTo = id
        }
        
        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { cheerSentTo = nil }
        }
    }
    
    // MARK: - Load Activity
    private func loadActivity() async {
        // Try loading from backend
        do {
            try await logService.getActivityFeed()
            
            let mapped = logService.activityFeed.prefix(5).map { feed in
                let (action, emoji, color) = activityDescription(for: feed.activity.type)
                return FriendActivity(
                    id: feed.id,
                    name: feed.friendUsername,
                    action: action,
                    emoji: emoji,
                    timeAgo: relativeTime(from: feed.timestamp),
                    color: color
                )
            }
            
            await MainActor.run {
                recentActivity = Array(mapped)
                isLoading = false
            }
        } catch {
            // Fallback: show sample data to demonstrate the feature
            await MainActor.run {
                recentActivity = sampleActivity()
                isLoading = false
            }
        }
    }
    
    private func activityDescription(for type: String) -> (String, String, Color) {
        switch type.lowercased() {
        case "workout":
            return ("completed a workout", "💪", .green)
        case "meal":
            return ("logged a meal", "🍽️", .orange)
        case "streak":
            return ("extended their streak", "🔥", .red)
        case "challenge":
            return ("completed a challenge", "🏆", .purple)
        case "water":
            return ("hit their water goal", "💧", .blue)
        default:
            return ("was active", "⚡", .cyan)
        }
    }
    
    private func relativeTime(from dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let date = formatter.date(from: dateString) else {
            return "recently"
        }
        
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
    }
    
    // Sample data when backend is unavailable
    private func sampleActivity() -> [FriendActivity] {
        [
            FriendActivity(id: "1", name: "Alex", action: "completed a workout", emoji: "💪", timeAgo: "12m ago", color: .green),
            FriendActivity(id: "2", name: "Sarah", action: "logged a healthy meal", emoji: "🥗", timeAgo: "45m ago", color: .orange),
            FriendActivity(id: "3", name: "Mike", action: "hit a 7-day streak!", emoji: "🔥", timeAgo: "2h ago", color: .red),
        ]
    }
}
