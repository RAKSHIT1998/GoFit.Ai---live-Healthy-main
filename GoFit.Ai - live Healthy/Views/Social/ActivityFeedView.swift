//
//  ActivityFeedView.swift
//  GoFit.Ai - live Healthy
//
//  Friends activity feed with reactions
//

import SwiftUI

struct ActivityFeedView: View {
    @StateObject private var sharingService = LogSharingService()
    @State private var feedItems: [ActivityFeed] = []
    @State private var isLoading = true
    @State private var reactedItems: Set<String> = []

    private let reactionEmojis = ["🔥", "❤️", "💪", "👏", "🎉"]

    var body: some View {
        ScrollView {
            if isLoading {
                loadingState
            } else if feedItems.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(feedItems, id: \.id) { item in
                        feedCard(item)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, Design.Spacing.md)
                .padding(.vertical, Design.Spacing.sm)
            }
        }
        .refreshable {
            await loadFeed()
        }
        .task {
            await loadFeed()
        }
    }

    // MARK: - Feed Card
    private func feedCard(_ item: ActivityFeed) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: avatar + name + time
            HStack(spacing: 10) {
                avatarCircle(name: item.friendUsername, isOwn: item.isOwnActivity)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.isOwnActivity ? "You" : item.friendUsername)
                        .font(Design.Typography.subheadline)
                        .fontWeight(.semibold)

                    Text(relativeTime(item.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                activityBadge(item.activity.type)
            }

            // Activity content
            VStack(alignment: .leading, spacing: 6) {
                if let title = item.activity.title, !title.isEmpty {
                    Text(title)
                        .font(Design.Typography.body)
                        .fontWeight(.medium)
                }

                if let desc = item.activity.description, !desc.isEmpty {
                    Text(desc)
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }

            Divider()

            // Reaction bar
            HStack(spacing: 0) {
                ForEach(reactionEmojis, id: \.self) { emoji in
                    Button {
                        _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            reactedItems.insert("\(item.id)-\(emoji)")
                        }
                        HapticManager.shared.lightTap()
                    } label: {
                        Text(emoji)
                            .font(.system(size: reactedItems.contains("\(item.id)-\(emoji)") ? 22 : 18))
                            .scaleEffect(reactedItems.contains("\(item.id)-\(emoji)") ? 1.2 : 1.0)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                reactedItems.contains("\(item.id)-\(emoji)")
                                    ? Design.Colors.primary.opacity(0.1)
                                    : Color.clear
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - Helpers
    private func avatarCircle(name: String, isOwn: Bool) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: isOwn
                        ? [Design.Colors.primary, Design.Colors.primary.opacity(0.7)]
                        : [.blue.opacity(0.6), .purple.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 40, height: 40)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            )
    }

    private func activityBadge(_ type: String) -> some View {
        let (icon, color, label) = activityMeta(type)
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private func activityMeta(_ type: String) -> (String, Color, String) {
        switch type.lowercased() {
        case "workout": return ("figure.run", .orange, "Workout")
        case "meal": return ("fork.knife", .green, "Meal")
        case "achievement": return ("trophy.fill", .yellow, "Achievement")
        case "challenge": return ("flag.fill", .purple, "Challenge")
        default: return ("bolt.fill", Design.Colors.primary, "Activity")
        }
    }

    private func relativeTime(_ timestamp: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: timestamp) ?? ISO8601DateFormatter().date(from: timestamp) else {
            return timestamp
        }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 604800 { return "\(Int(interval / 86400))d ago" }
        let df = DateFormatter()
        df.dateStyle = .short
        return df.string(from: date)
    }

    // MARK: - States
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading activity feed...")
                .font(Design.Typography.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundColor(Design.Colors.primary.opacity(0.25))

            VStack(spacing: 8) {
                Text("No activity yet")
                    .font(Design.Typography.headline)
                    .foregroundColor(.secondary)
                Text("When friends share workouts or meals,\nthey'll appear here!")
                    .font(Design.Typography.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Data
    @MainActor
    private func loadFeed() async {
        isLoading = feedItems.isEmpty
        do {
            try await sharingService.getActivityFeed()
            withAnimation(.easeOut(duration: 0.25)) {
                feedItems = sharingService.activityFeed
                isLoading = false
            }
        } catch {
            isLoading = false
        }
    }
}
