//
//  ActivityFeedView.swift
//  GoFit.Ai - live Healthy
//
//  Friends activity feed with reactions
//

import SwiftUI

struct ActivityFeedView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var sharingService = LogSharingService()
    @State private var feedItems: [ActivityFeed] = []
    @State private var isLoading = true
    @State private var reactedItems: Set<String> = []
    @State private var likedPosts: Set<String> = []
    @State private var composerText: String = ""
    @State private var selectedPostType: String = "Achievement"
    @State private var isPosting: Bool = false
    @State private var postError: String? = nil
    @State private var socialEngagementPoints: Int = 0
    @State private var showSocialMVPBadge: Bool = false

    private let reactionEmojis = ["🔥", "❤️", "💪", "👏", "🎉"]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                postComposerSection
                weeklyChallengeCard
                inviteTodayCard

                if showSocialMVPBadge {
                    HStack {
                        Image(systemName: "rosette")
                        Text("Social MVP unlocked! Keep the engagement going 🎉")
                            .font(Design.Typography.caption)
                    }
                    .padding(12)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(14)
                    .padding(.horizontal, Design.Spacing.md)
                }

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
            .padding(.vertical, Design.Spacing.sm)
        }
        .refreshable {
            await loadFeed()
        }
        .task {
            await loadFeed()
        }
        .onReceive(WebSocketService.shared.$latestActivityFeed) { feed in
            guard let feed = feed else { return }
            withAnimation(.easeIn(duration: 0.2)) {
                if !feedItems.contains(where: { $0.id == feed.id }) {
                    feedItems.insert(feed, at: 0)
                    if feedItems.count > 50 { feedItems.removeLast() }
                }
            }
            socialEngagementPoints += 2
            checkSocialMVPStatus()
        }
    }

    // MARK: - Post Composer
    private var postComposerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Share your progress")
                .font(Design.Typography.subheadline)
                .fontWeight(.semibold)

            TextEditor(text: $composerText)
                .frame(minHeight: 80, maxHeight: 130)
                .padding(8)
                .background(Design.Colors.cardBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                )

            HStack(spacing: 10) {
                Picker("Type", selection: $selectedPostType) {
                    ForEach(["Achievement", "Workout", "Meal", "Challenge", "Social"], id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Button(action: postActivity) {
                    if isPosting {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Text("Post")
                            .fontWeight(.bold)
                    }
                }
                .disabled(composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                .buttonStyle(.borderedProminent)
            }

            if let postError {
                Text(postError)
                    .font(Design.Typography.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, Design.Spacing.md)
    }

    private var weeklyChallengeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "flag.checkered")
                    .foregroundColor(Design.Colors.primary)
                Text("Weekly #GoFit Challenge")
                    .font(Design.Typography.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            Text("Complete 5 workouts + share 3 posts this week to unlock bonus XP and your Social MVP badge!")
                .font(Design.Typography.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Button("Join Challenge") {
                    postActivityForChallenge() // small helper
                }
                .buttonStyle(.borderedProminent)

                Button("View Rules") {
                    // For MVP, open a lightweight modal in the future
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, Design.Spacing.md)
    }

    private var inviteTodayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "megaphone.fill")
                    .foregroundColor(Design.Colors.secondary)
                Text("Invite Today")
                    .font(Design.Typography.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            Text("Tag a friend in your next post and refer them with your code for a bonus Social points boost!")
                .font(Design.Typography.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                Button("Tag Friend") {
                    shareInviteSnippet()
                }
                .buttonStyle(.borderedProminent)

                Button("Show Code") {
                    if let code = ReferralManager.shared.referralCode, !code.isEmpty {
                        postError = "Your code: \(code)"
                    } else {
                        let generated = ReferralManager.shared.generateCode(for: auth.userId ?? "user", name: auth.name)
                        postError = "Your code: \(generated)"
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, Design.Spacing.md)
    }

    private func postActivityForChallenge() {
        socialEngagementPoints += 10
        checkSocialMVPStatus()
        HapticManager.shared.success()
    }

    private func shareInviteSnippet() {
        let referral = ReferralManager.shared.referralCode.isEmpty
            ? ReferralManager.shared.generateCode(for: auth.userId ?? "user", name: auth.name)
            : ReferralManager.shared.referralCode

        let text = "Join me on GoFit.Ai! Use code \(referral) and challenge #GoFit this week!"
        let shareSheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(shareSheet, animated: true)
        }
    }

    private func checkSocialMVPStatus() {
        if socialEngagementPoints >= 10 {
            showSocialMVPBadge = true
            NotificationService.shared.sendNowNotification(
                title: "Social MVP!",
                body: "You earned the Social MVP badge for outstanding engagement!"
            )
        }
    }

    private func postActivity() {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isPosting = true
        postError = nil

        let now = Date()
        let isoFmt = ISO8601DateFormatter()
        let timestamp = isoFmt.string(from: now)

        let sharedActivity = SharedActivityLog(
            id: UUID().uuidString,
            userId: auth.userId ?? "anonymous",
            username: auth.name.isEmpty ? "You" : auth.name,
            type: selectedPostType.lowercased(),
            title: "\(selectedPostType) Update",
            description: text,
            visibility: "public",
            sharedWith: nil,
            createdAt: timestamp,
            updatedAt: nil
        )

        let newFeed = ActivityFeed(
            id: UUID().uuidString,
            activity: sharedActivity,
            friendUsername: sharedActivity.username ?? "You",
            timestamp: timestamp,
            isOwnActivity: true
        )

        withAnimation(.spring()) {
            feedItems.insert(newFeed, at: 0)
            if feedItems.count > 50 { feedItems.removeLast() }
        }

        composerText = ""
        isPosting = false

        socialEngagementPoints += 1
        checkSocialMVPStatus()

        Task {
            do {
                try await sharingService.postFeedActivity(sharedActivity)
            } catch {
                postError = "Could not publish to server. Saved locally."
            }
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
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        if likedPosts.contains(item.id) {
                            likedPosts.remove(item.id)
                            if let index = feedItems.firstIndex(where: { $0.id == item.id }) {
                                feedItems[index].totalLikes = max(0, feedItems[index].totalLikes - 1)
                                feedItems[index].isLikedByCurrentUser = false
                            }
                        } else {
                            likedPosts.insert(item.id)
                            if let index = feedItems.firstIndex(where: { $0.id == item.id }) {
                                feedItems[index].totalLikes += 1
                                feedItems[index].isLikedByCurrentUser = true
                            }
                            socialEngagementPoints += 1
                            checkSocialMVPStatus()
                        }
                    }
                    HapticManager.shared.lightTap()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: likedPosts.contains(item.id) ? "heart.fill" : "heart")
                            .foregroundColor(likedPosts.contains(item.id) ? .red : .secondary)
                        Text("\(item.totalLikes)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    postComment(on: item)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .foregroundColor(.secondary)
                        Text("\(item.totalComments)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    shareFeedItem(item)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
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

    private func postComment(on item: ActivityFeed) {
        guard let index = feedItems.firstIndex(where: { $0.id == item.id }) else { return }
        feedItems[index].totalComments += 1
        socialEngagementPoints += 2
        checkSocialMVPStatus()
        HapticManager.shared.notification(type: .success)
    }

    private func shareFeedItem(_ item: ActivityFeed) {
        let message = "\(item.friendUsername)'s post: \(item.activity.title ?? "Update") - \(item.activity.description ?? "")"
        let activityVC = UIActivityViewController(activityItems: [message], applicationActivities: nil)

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return }
        rootVC.present(activityVC, animated: true)
    }
}

