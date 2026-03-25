//
//  SocialHubView.swift
//  GoFit.Ai - live Healthy
//
//  Social Hub: Feed + Chats + Friends + Leaderboard + Challenges
//

import SwiftUI

struct SocialHubView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var purchases: PurchaseManager
    @ObservedObject private var friendsService = FriendsService.shared
    @StateObject private var aiChallenges = AIChallengeService.shared
    @StateObject private var challengeService = ChallengeService()

    @State private var selectedTab: SocialTab = .clubs
    @State private var showQuickAdd = false
    @State private var showRunTracker = false
    @State private var showCreateChallenge = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPaywall = false
    @State private var searchText = ""
    @ObservedObject private var runClubService = RunClubService.shared
    @State private var clubCityFilter = ""
    @State private var showCreateClubSheet = false

    enum SocialTab: String, CaseIterable {
        case clubs = "Clubs"
        case friendsChats = "Friends & Chats"

        var icon: String {
            switch self {
            case .clubs: return "person.3.fill"
            case .friendsChats: return "bubble.left.and.bubble.right"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                scrollableTabBar

                inviteTodayBanner

                switch selectedTab {
                case .clubs:
                    runClubsSection
                case .friendsChats:
                    friendsChatsSection
                }
            }
            .background(Design.Colors.background.ignoresSafeArea())
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showRunTracker = true
                            HapticManager.shared.lightTap()
                        } label: {
                            Image(systemName: "figure.run")
                                .font(.body)
                                .foregroundColor(Design.Colors.primary)
                        }

                        Button {
                            showQuickAdd = true
                            HapticManager.shared.lightTap()
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .font(.body)
                                .foregroundColor(Design.Colors.primary)
                        }
                    }
                }
            }
            .onAppear {
                friendsService.fetchFriends { _ in }
                friendsService.fetchFriendRequests { _ in }

                Task {
                    if purchases.isPremiumActive {
                        await aiChallenges.generateChallenges()
                    }
                    try? await challengeService.getChallenges()
                }
            }
            .alert(errorMessage.lowercased().contains("fail") || errorMessage.lowercased().contains("error") ? "Error" : "Success", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(purchases)
            }
            .sheet(isPresented: $showQuickAdd) {
                QuickAddFriendSheet()
                    .environmentObject(auth)
            }
            .sheet(isPresented: $showCreateChallenge) {
                CreateChallengeView()
                    .environmentObject(auth)
            }
            .sheet(isPresented: $showRunTracker) {
                RunTrackerView()
                    .environmentObject(auth)
            }
        }
    }

    private var inviteTodayBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "megaphone.fill")
                .foregroundColor(Design.Colors.primary)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text("Invite Today")
                    .font(Design.Typography.caption)
                    .fontWeight(.semibold)
                Text("Tag friends in your post + use your code to earn Social MVP points!")
                    .font(Design.Typography.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                let code = ReferralManager.shared.referralCode.isEmpty ? ReferralManager.shared.generateCode(for: auth.userId ?? "user", name: auth.name) : ReferralManager.shared.referralCode
                let shareText = "Join GoFit.Ai with my code: \(code) and crush the #GoFit challenge!"
                let sheet = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController {
                    root.present(sheet, animated: true)
                }
            } label: {
                Text("Invite")
                    .font(Design.Typography.caption2)
                    .fontWeight(.bold)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Design.Colors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding(12)
        .background(Design.Colors.cardBackground)
        .cornerRadius(14)
        .shadow(color: Color.primary.opacity(0.06), radius: 4, x: 0, y: 2)
        .padding(.horizontal, Design.Spacing.md)
        .padding(.vertical, 6)
    }

    // MARK: - Scrollable Tab Bar
    private var scrollableTabBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SocialTab.allCases, id: \ .self) { tab in
                        let isSelected = selectedTab == tab
                        let tabText = Text(tab.rawValue)
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                        let tabIcon = Image(systemName: tab.icon)
                            .font(.system(size: 12))
                        let badge: Text? = {
                            if tab == .friends && friendsService.friendRequests.count > 0 {
                                return Text("\(friendsService.friendRequests.count)")
                                    .font(.system(size: 9, weight: .bold))
                            } else {
                                return nil
                            }
                        }()
                                .foregroundColor(.white)
                                .frame(width: 16, height: 16)
                                .background(Color.red)
                                .clipShape(Circle())
                            : nil
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                            HapticManager.shared.lightTap()
                        } label: {
                            HStack(spacing: 6) {
                                tabIcon
                                tabText
                                if let badge = badge { badge }
                            }
                            .foregroundColor(isSelected ? .white : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Group {
                                    if isSelected {
                                        Capsule().fill(Design.Colors.primaryGradient)
                                    } else {
                                        Capsule().fill(Color.gray.opacity(0.08))
                                    }
                                }
                            )
                        }
                        .id(tab)
                    }
                }
                .padding(.horizontal, Design.Spacing.md)
                .padding(.vertical, 8)
            }
            .background(Design.Colors.background)
            .onChange(of: selectedTab) { _, newTab in
                withAnimation { proxy.scrollTo(newTab, anchor: .center) }
            }
        }
    }

    // MARK: - Friends Section
    private var friendsChatsSection: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.md) {
                if friendsService.friends.isEmpty {
                    emptyFriendsState
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Friends & Chats")
                            .font(Design.Typography.headline)
                            .padding(.horizontal, Design.Spacing.md)
                        ForEach(friendsService.friends, id: \.id) { friend in
                            NavigationLink(destination: ChatView(friend: friend, currentUserId: auth.userId ?? "")) {
                                FriendCardView(friend: friend, currentUserId: auth.userId ?? "")
                                    .padding(.horizontal, Design.Spacing.md)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, Design.Spacing.md)
        }
        .refreshable {
            friendsService.fetchFriends { _ in }
            friendsService.fetchFriendRequests { _ in }
        }
    }

    private var runClubsSection: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.lg) {
                HStack {
                    Text("Run Clubs")
                        .font(Design.Typography.headline)
                    Spacer()
                    Button {
                        showCreateClubSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                        Text("Create Club")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, Design.Spacing.md)

                TextField("Filter by city", text: $clubCityFilter)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, Design.Spacing.md)

                ForEach(runClubService.getClubs(city: clubCityFilter)) { club in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(club.name)
                                .font(Design.Typography.headline)
                            Spacer()
                            Button(club.members.contains(where: { $0.userId == auth.userId }) ? "Joined" : "Join") {
                                if let userId = auth.userId {
                                    if club.members.contains(where: { $0.userId == userId }) {
                                        runClubService.leaveClub(club.id, userId: userId)
                                    } else {
                                        runClubService.joinClub(club.id, userId: userId, username: auth.name)
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        Text(club.description ?? "No description")
                            .font(Design.Typography.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Label(club.city ?? "Global", systemImage: "map.fill")
                                .font(Design.Typography.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Share Link") {
                                let link = "gofit://runclub/\(club.id)"
                                let shareText = "Join our Run Club \(club.name)! \(link)"
                                let vc = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
                                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let root = scene.windows.first?.rootViewController {
                                    root.present(vc, animated: true)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(16)
                    .background(Design.Colors.cardBackground)
                    .cornerRadius(14)
                    .padding(.horizontal, Design.Spacing.md)
                    .onTapGesture {
                        runClubService.selectedClub = club
                    }
                }
                Spacer()
            }
            .padding(.vertical, Design.Spacing.md)
        }
        .sheet(isPresented: $showCreateClubSheet) {
            CreateRunClubSheet(isPresented: $showCreateClubSheet) { club in
                runClubService.selectedClub = club
            }
            .environmentObject(auth)
            .environmentObject(runClubService)
        }
        .sheet(item: $runClubService.selectedClub) { club in
            RunClubDetailView(runClubService: runClubService, club: club)
                .environmentObject(auth)
                .environmentObject(runClubService)
        }
    }

    private var emptyFriendsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(Design.Colors.primary.opacity(0.3))
            Text("No friends yet")
                .font(Design.Typography.headline)
                .foregroundColor(.secondary)
            Text("Search above or invite friends to connect!")
                .font(Design.Typography.caption)
                .foregroundColor(.secondary)

            Button {
                showQuickAdd = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus")
                    Text("Add Friends")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Design.Colors.primary)
                .cornerRadius(14)
            }
            .buttonStyle(SmoothButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }

    // MARK: - Search Results
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            if friendsService.isLoading {
                HStack {
                    ProgressView()
                    Text("Searching...")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else if friendsService.searchResults.isEmpty && !searchText.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    Text("No results for \"\(searchText)\"")
                        .font(Design.Typography.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ForEach(friendsService.searchResults, id: \.id) { result in
                    SearchResultRow(result: result) { userId in
                        friendsService.sendFriendRequest(to: userId) { _ in }
                    }
                }
                .padding(.horizontal, Design.Spacing.md)
            }
        }
    }

    // MARK: - Leaderboard Section
    private var leaderboardSection: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.lg) {
                FriendsLeaderboardCard()
                    .padding(.horizontal, Design.Spacing.md)

                badgesPreview
            }
            .padding(.vertical, Design.Spacing.md)
        }
    }

    private var badgesPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "medal.fill")
                    .foregroundColor(.purple)
                Text("Achievements")
                    .font(Design.Typography.headline)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    achievementChip(emoji: "\u{1F525}", title: "Streak Master", desc: "7-day streak", color: .orange)
                    achievementChip(emoji: "\u{1F4AA}", title: "Iron Will", desc: "50 workouts", color: .red)
                    achievementChip(emoji: "\u{1F957}", title: "Clean Eater", desc: "100 meals logged", color: .green)
                    achievementChip(emoji: "\u{1F4A7}", title: "Hydrated", desc: "Water goals x30", color: .blue)
                    achievementChip(emoji: "\u{1F3C3}", title: "Step King", desc: "10k steps x7", color: .purple)
                    achievementChip(emoji: "\u{1F3C6}", title: "Social MVP", desc: "10+ interactions", color: .pink)
                }
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        .padding(.horizontal, Design.Spacing.md)
    }

    private func achievementChip(emoji: String, title: String, desc: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 28))
                .frame(width: 52, height: 52)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(desc)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 90)
        .padding(.vertical, 10)
        .background(color.opacity(0.04))
        .cornerRadius(14)
    }

    // MARK: - Challenges Section
    private var challengesSection: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.lg) {
                if !challengeService.challenges.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.blue)
                            Text("Friend Challenges")
                                .font(Design.Typography.headline)
                            Spacer()
                        }
                        .padding(.horizontal, Design.Spacing.md)

                        ForEach(challengeService.challenges) { challenge in
                            friendChallengeCard(challenge)
                                .padding(.horizontal, Design.Spacing.md)
                        }
                    }
                }

                createChallengePrompt
                    .padding(.horizontal, Design.Spacing.md)

                Divider()
                    .padding(.horizontal, Design.Spacing.md)

                if !purchases.isPremiumActive {
                    aiPremiumUpsell
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "brain.head.profile")
                                        .foregroundColor(.purple)
                                    Text("AI Challenges")
                                        .font(Design.Typography.headline)
                                    Text("PRO")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(LinearGradient(colors: [Design.Colors.primary, .purple], startPoint: .leading, endPoint: .trailing))
                                        .cornerRadius(4)
                                }
                                Text("\(aiChallenges.activeChallenges.count) active \u{2022} \(aiChallenges.totalXPEarned) XP earned")
                                    .font(Design.Typography.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            Button {
                                Task { await aiChallenges.generateChallenges(forceRefresh: true) }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.body.weight(.medium))
                                    .foregroundColor(Design.Colors.primary)
                            }
                        }
                        .padding(.horizontal, Design.Spacing.md)

                        if aiChallenges.isGenerating {
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Generating challenges...")
                                    .font(Design.Typography.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                        } else if aiChallenges.activeChallenges.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundColor(Design.Colors.primary.opacity(0.4))
                                Text("No active challenges")
                                    .font(Design.Typography.body)
                                    .foregroundColor(.secondary)
                                Button {
                                    Task { await aiChallenges.generateChallenges(forceRefresh: true) }
                                } label: {
                                    Text("Generate Challenges")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Design.Colors.primary)
                                        .cornerRadius(12)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                        } else {
                            ForEach(aiChallenges.activeChallenges) { challenge in
                                AIChallengeCard(challenge: challenge)
                            }
                            .padding(.horizontal, Design.Spacing.md)
                        }
                    }
                }
            }
            .padding(.vertical, Design.Spacing.md)
        }
        .refreshable {
            try? await challengeService.getChallenges()
            if purchases.isPremiumActive {
                await aiChallenges.generateChallenges(forceRefresh: true)
            }
        }
    }

    private var createChallengePrompt: some View {
        Button {
            showCreateChallenge = true
            HapticManager.shared.lightTap()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Challenge a Friend")
                        .font(Design.Typography.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Steps, calories, workouts \u{2014} you pick!")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Design.Colors.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func friendChallengeCard(_ challenge: Challenge) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(challenge.name)
                        .font(Design.Typography.subheadline)
                        .fontWeight(.bold)

                    if let desc = challenge.description {
                        Text(desc)
                            .font(Design.Typography.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(challenge.status.rawValue.capitalized)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(challenge.status == .active ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(challenge.status == .active ? Color.green.opacity(0.12) : Color.gray.opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack(spacing: 16) {
                Label(challenge.metric.replacingOccurrences(of: "_", with: " ").capitalized, systemImage: "target")
                    .font(Design.Typography.caption2)
                    .foregroundColor(.secondary)

                Label(challenge.type.rawValue.replacingOccurrences(of: "_", with: " "), systemImage: "person.2")
                    .font(Design.Typography.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Design.Colors.cardBackground)
        .cornerRadius(14)
        .shadow(color: Color.primary.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    // MARK: - AI Premium Upsell
    private var aiPremiumUpsell: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Design.Colors.primary.opacity(0.15), Color.purple.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 120, height: 120)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 50))
                    .foregroundStyle(LinearGradient(colors: [Design.Colors.primary, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            }

            VStack(spacing: 12) {
                Text("Smart AI Challenges")
                    .font(.title2.weight(.bold))
                Text("Your personal AI coach creates challenges that push you beyond your comfort zone.")
                    .font(Design.Typography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }

            VStack(alignment: .leading, spacing: 14) {
                PremiumFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Adapts to your fitness level", color: .green)
                PremiumFeatureRow(icon: "target", text: "Personalized daily targets", color: .orange)
                PremiumFeatureRow(icon: "star.fill", text: "Earn XP and achievements", color: .yellow)
                PremiumFeatureRow(icon: "person.2.fill", text: "Challenge your friends", color: .blue)
            }
            .padding(.horizontal, 30)

            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                    Text("Unlock AI Challenges \u{2014} Go Premium")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [Design.Colors.primary, .purple], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(16)
                .shadow(color: Design.Colors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(SmoothButtonStyle())
            .padding(.horizontal, 30)

            Spacer()
        }
    }
}

// MARK: - Stat Chip
struct StatChip: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.primary)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Design.Colors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: SearchResult
    let onAdd: (String) -> Void
    @State private var sendState: SendState = .idle

    enum SendState { case idle, sending, sent, failed }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(result.username.prefix(1)).uppercased())
                        .font(.headline).foregroundColor(.white)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(result.fullName ?? result.username)
                    .font(Design.Typography.subheadline).fontWeight(.semibold).foregroundColor(.primary)
                Text("@\(result.username)")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()

            if result.friendStatus == "friends" {
                Label("Friend", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundColor(.green)
            } else if result.friendStatus == "request_sent" || sendState == .sent {
                Label("Sent", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold)).foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            } else if sendState == .sending {
                ProgressView().frame(width: 40, height: 40)
            } else {
                Button {
                    sendState = .sending
                    HapticManager.shared.lightTap()
                    onAdd(result.id)
                    withAnimation(.spring(response: 0.3)) { sendState = .sent }
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.title3).foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Design.Colors.primary)
                        .clipShape(Circle())
                }
                .buttonStyle(SmoothButtonStyle())
            }
        }
        .padding(Design.Spacing.md)
        .background(Design.Colors.cardBackground)
        .cornerRadius(14)
    }
}

// MARK: - Quick Add Friend Sheet
struct QuickAddFriendSheet: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject private var friendsService = FriendsService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Name, email, or username", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit { friendsService.searchUsers(query: searchText) { _ in } }
                    if !searchText.isEmpty {
                        Button { searchText = ""; friendsService.searchResults = [] } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, Design.Spacing.md)
                .padding(.top, Design.Spacing.sm)
                .onChange(of: searchText) { _, newValue in
                    guard newValue.count >= 2 else { friendsService.searchResults = []; return }
                    Task {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        guard searchText == newValue else { return }
                        friendsService.searchUsers(query: newValue) { _ in }
                    }
                }

                Divider().padding(.top, 12)

                if friendsService.isLoading && friendsService.searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 8) { ProgressView(); Text("Searching...").font(.caption).foregroundColor(.secondary) }
                    Spacer()
                } else if friendsService.searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: searchText.count < 2 ? "person.badge.plus" : "magnifyingglass")
                            .font(.system(size: 44)).foregroundColor(Design.Colors.primary.opacity(0.3))
                        Text(searchText.count < 2 ? "Find friends by name or email" : "No results for \"\(searchText)\"")
                            .font(Design.Typography.body).foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(friendsService.searchResults, id: \.id) { result in
                                SearchResultRow(result: result) { userId in
                                    friendsService.sendFriendRequest(to: userId) { _ in }
                                }
                            }
                        }
                        .padding(.horizontal, Design.Spacing.md)
                        .padding(.vertical, Design.Spacing.sm)
                    }
                }

                ShareLink(item: inviteText, subject: Text("Join me on GoFit.Ai!"), message: Text(inviteText)) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Invite via Link").fontWeight(.semibold)
                    }
                    .foregroundColor(Design.Colors.primary)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Design.Colors.primary.opacity(0.1)).cornerRadius(14)
                }
                .padding(.horizontal, Design.Spacing.md).padding(.bottom, Design.Spacing.md)
            }
            .navigationTitle("Add Friend").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } } }
            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isSearchFocused = true } }
        }
    }

    private var inviteText: String {
        let name = auth.name.isEmpty ? "Someone" : auth.name
        return "Hey! \u{1F4AA} \(name) wants you to join GoFit.Ai \u{2014} the AI fitness app!\n\nDownload: https://apps.apple.com/app/gofit-ai"
    }
}

// MARK: - AI Challenge Card
struct AIChallengeCard: View {
    let challenge: AIChallenge

    var body: some View {
        VStack(spacing: Design.Spacing.md) {
            HStack(spacing: 12) {
                Text(challenge.icon)
                    .font(.title).frame(width: 50, height: 50)
                    .background(challenge.category.color.opacity(0.15)).cornerRadius(14)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(challenge.title).font(Design.Typography.subheadline).fontWeight(.bold).foregroundColor(.primary)
                        HStack(spacing: 2) {
                            ForEach(0..<challenge.difficulty.stars, id: \.self) { _ in
                                Image(systemName: "star.fill").font(.system(size: 8)).foregroundColor(challenge.difficulty.color)
                            }
                        }
                    }
                    Text(challenge.category.label).font(.caption2).foregroundColor(challenge.category.color)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(challenge.category.color.opacity(0.1)).cornerRadius(6)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if challenge.isCompleted {
                        Image(systemName: "checkmark.circle.fill").font(.title2).foregroundColor(.green)
                    } else {
                        Text("+\(challenge.xpReward) XP").font(.caption.weight(.bold)).foregroundColor(Design.Colors.primary)
                    }
                    Text(challenge.timeRemainingText).font(.caption2).foregroundColor(.secondary)
                }
            }
            Text(challenge.description).font(Design.Typography.caption).foregroundColor(.secondary).lineLimit(2)
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.1)).frame(height: 10)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: challenge.isCompleted ? [.green] : [challenge.category.color, challenge.category.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * challenge.progressPercent, height: 10)
                            .animation(.easeInOut(duration: 0.3), value: challenge.progressPercent)
                    }
                }
                .frame(height: 10)
                HStack {
                    Text("\(Int(challenge.currentProgress))/\(Int(challenge.targetValue)) \(challenge.unit)").font(.caption2).foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(challenge.progressPercent * 100))%").font(.caption2.weight(.semibold)).foregroundColor(challenge.category.color)
                }
            }
        }
        .padding(Design.Spacing.md)
        .background(Design.Colors.cardBackground).cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Premium Feature Row
struct PremiumFeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.body).foregroundColor(color).frame(width: 32)
            Text(text).font(Design.Typography.body).foregroundColor(.primary)
            Spacer()
        }
    }
}

// MARK: - Run Club Sheets
struct CreateRunClubSheet: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var runClubService: RunClubService
    @Binding var isPresented: Bool
    var onCreated: (RunClub) -> Void = { _ in }

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var city: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Club Information")) {
                    TextField("Club name", text: $name)
                    TextField("Description", text: $description)
                    TextField("City", text: $city)
                }
            }
            .navigationTitle("Create Run Club")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        guard !name.isEmpty, let userId = auth.userId else { return }
                        let club = runClubService.createClub(name: name, description: description, city: city, ownerId: userId, ownerName: auth.name)
                        runClubService.selectedClub = club
                        onCreated(club)
                        isPresented = false
                    }
                    .disabled(name.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}

struct RunClubDetailView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject var runClubService: RunClubService
    @State var club: RunClub

    @State private var newEventTitle = ""
    @State private var newEventDetails = ""
    @State private var newEventLocation = ""
    @State private var newEventDate = Date()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text(club.description ?? "No description")
                        .font(Design.Typography.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Label(club.city ?? "Global", systemImage: "map.fill")
                            .font(Design.Typography.caption2)
                        Spacer()
                        Text("Members: \(club.members.count)")
                            .font(Design.Typography.caption2)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Upcoming Runs")
                            .font(Design.Typography.subheadline)
                            .fontWeight(.semibold)

                        if let updatedClub = runClubService.clubs.first(where: { $0.id == club.id }) {
                            ForEach(updatedClub.events) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title)
                                        .font(Design.Typography.bodyBold)
                                    Text(event.details ?? "")
                                        .font(Design.Typography.caption)
                                    Text("\(event.location ?? "TBD") • \(event.date, style: .date) \(event.date, style: .time)")
                                        .font(Design.Typography.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(Design.Colors.cardBackground)
                                .cornerRadius(12)
                            }
                            if updatedClub.events.isEmpty {
                                Text("No planned runs yet. Club owner can add events.")
                                    .font(Design.Typography.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if club.ownerId == auth.userId {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Plan a New Run")
                                .font(Design.Typography.subheadline)
                                .fontWeight(.semibold)

                            TextField("Title", text: $newEventTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            TextField("Details", text: $newEventDetails)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            TextField("Location", text: $newEventLocation)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            DatePicker("Date", selection: $newEventDate, displayedComponents: [.date, .hourAndMinute])

                            Button("Post Run Event") {
                                guard !newEventTitle.isEmpty else { return }
                                runClubService.addEvent(to: club.id, title: newEventTitle, details: newEventDetails, location: newEventLocation, date: newEventDate, createdBy: auth.name)
                                if let updated = runClubService.clubs.first(where: { $0.id == club.id }) {
                                    club = updated
                                }
                                newEventTitle = ""
                                newEventDetails = ""
                                newEventLocation = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newEventTitle.isEmpty)
                        }
                        .padding(16)
                        .background(Design.Colors.cardBackground)
                        .cornerRadius(14)
                    }

                    Button("Share club link") {
                        let invite = "Join our run club \(club.name): gofit://runclub/\(club.id)"
                        let activityVC = UIActivityViewController(activityItems: [invite], applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            root.present(activityVC, animated: true)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(Design.Spacing.md)
            }
            .navigationTitle(club.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        runClubService.selectedClub = nil
                    }
                }
            }
            .onDisappear {
                runClubService.selectedClub = nil
            }
        }
    }
}
