//
//  SocialHubView.swift
//  GoFit.Ai - live Healthy
//
//  Social Hub: Friends + Chat + Daily Log Sharing + AI Challenges
//

import SwiftUI

struct SocialHubView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var purchases: PurchaseManager
    @ObservedObject private var friendsService = FriendsService.shared
    @StateObject private var aiChallenges = AIChallengeService.shared
    
    @State private var selectedSection: SocialSection = .friends
    @State private var searchText = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPaywall = false
    @State private var showQuickAdd = false
    
    enum SocialSection: String, CaseIterable {
        case friends = "Friends"
        case aiChallenges = "AI Challenges"
        case chats = "Chats"
        
        var icon: String {
            switch self {
            case .friends: return "person.2.fill"
            case .aiChallenges: return "brain.head.profile"
            case .chats: return "bubble.left.and.bubble.right.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    socialStatsBanner
                    sectionPicker
                    
                    Divider()
                        .padding(.top, 4)
                    
                    TabView(selection: $selectedSection) {
                        friendsSection
                            .tag(SocialSection.friends)
                        
                        aiChallengesSection
                            .tag(SocialSection.aiChallenges)
                        
                        chatsSection
                            .tag(SocialSection.chats)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("Social")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showQuickAdd = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                            .foregroundColor(Design.Colors.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if friendsService.friendRequests.count > 0 {
                        Button {
                            selectedSection = .friends
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(Design.Colors.primary)
                                
                                Text("\(friendsService.friendRequests.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -6)
                            }
                        }
                    }
                }
            }
            .onAppear {
                friendsService.fetchFriends { _ in }
                friendsService.fetchFriendRequests { _ in }
                
                if purchases.isPremiumActive {
                    Task {
                        await aiChallenges.generateChallenges()
                    }
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
        }
    }
    
    // MARK: - Stats Banner
    private var socialStatsBanner: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StatChip(icon: "person.2.fill", value: "\(friendsService.friends.count)", label: "Friends", color: Design.Colors.primary)
                StatChip(icon: "envelope.fill", value: "\(friendsService.friendRequests.count)", label: "Requests", color: .orange)
                StatChip(icon: "bolt.fill", value: "\(aiChallenges.activeChallenges.count)", label: "Challenges", color: .purple)
                StatChip(icon: "flame.fill", value: "\(StreakManager.shared.currentStreak)", label: "Streak", color: .red)
                
                if purchases.isPremiumActive {
                    StatChip(icon: "star.fill", value: "\(aiChallenges.totalXPEarned)", label: "AI XP", color: .yellow)
                }
                
                // Share progress chip
                ShareLink(
                    item: ViralEngagementManager.motivationalShareTexts.randomElement() ?? "Check out GoFit.Ai! #GoFitAi",
                    subject: Text("My GoFit.Ai Progress"),
                    message: Text(NutritionBroadcaster.shared.formattedSummary)
                ) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.caption)
                        Text("Share")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, Design.Spacing.md)
            .padding(.vertical, Design.Spacing.sm)
        }
    }
    
    // MARK: - Section Picker
    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(SocialSection.allCases, id: \.self) { section in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSection = section
                        }
                        HapticManager.shared.lightTap()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: section.icon)
                                .font(.caption)
                            Text(section.rawValue)
                                .font(.subheadline.weight(.semibold))
                            
                            if section == .aiChallenges && !purchases.isPremiumActive {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundColor(.yellow)
                            }
                            
                            if section == .friends && friendsService.friendRequests.count > 0 {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .foregroundColor(selectedSection == section ? .white : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(selectedSection == section ? Design.Colors.primary : Design.Colors.cardBackground)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, Design.Spacing.md)
        }
    }
    
    // MARK: - Friends Section
    private var friendsSection: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.lg) {
                SearchBar(text: $searchText, placeholder: "Search by email, name, or username") { query in
                    guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
                        friendsService.searchResults = []
                        return
                    }
                    friendsService.searchUsers(query: query) { _ in }
                }
                .padding(.horizontal, Design.Spacing.md)
                
                if !searchText.isEmpty {
                    searchResultsView
                }
                
                if !friendsService.friendRequests.isEmpty {
                    VStack(alignment: .leading, spacing: Design.Spacing.sm) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.orange)
                            Text("Requests (\(friendsService.friendRequests.count))")
                                .font(Design.Typography.headline)
                            Spacer()
                        }
                        .padding(.horizontal, Design.Spacing.md)
                        
                        ForEach(friendsService.friendRequests, id: \.id) { request in
                            FriendRequestCardView(request: request, onAccept: {
                                friendsService.acceptFriendRequest(from: request.requesterId) { _ in
                                    friendsService.fetchFriendRequests { _ in }
                                    friendsService.fetchFriends { _ in }
                                }
                            }, onDecline: {
                                friendsService.rejectFriendRequest(from: request.requesterId) { _ in
                                    friendsService.fetchFriendRequests { _ in }
                                }
                            })
                        }
                        .padding(.horizontal, Design.Spacing.md)
                    }
                }
                
                VStack(alignment: .leading, spacing: Design.Spacing.sm) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(Design.Colors.primary)
                        Text("Your Friends (\(friendsService.friends.count))")
                            .font(Design.Typography.headline)
                        Spacer()
                    }
                    .padding(.horizontal, Design.Spacing.md)
                    
                    if friendsService.friends.isEmpty {
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
                    } else {
                        ForEach(friendsService.friends, id: \.id) { friend in
                            FriendCardView(friend: friend, currentUserId: auth.userId ?? "")
                        }
                        .padding(.horizontal, Design.Spacing.md)
                    }
                }
            }
            .padding(.vertical, Design.Spacing.md)
        }
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
    
    // MARK: - AI Challenges Section (Premium)
    private var aiChallengesSection: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.lg) {
                if !purchases.isPremiumActive {
                    aiPremiumUpsell
                } else {
                    aiChallengeHeader
                    
                    if aiChallenges.isGenerating {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("AI is analyzing your fitness data...")
                                .font(Design.Typography.body)
                                .foregroundColor(.secondary)
                            Text("Generating personalized challenges")
                                .font(Design.Typography.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else if aiChallenges.activeChallenges.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 50))
                                .foregroundStyle(LinearGradient(colors: [Design.Colors.primary, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            Text("Ready to generate challenges!")
                                .font(Design.Typography.headline)
                            
                            Button {
                                Task { await aiChallenges.generateChallenges(forceRefresh: true) }
                            } label: {
                                HStack {
                                    Image(systemName: "brain.head.profile")
                                    Text("Generate AI Challenges")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(LinearGradient(colors: [Design.Colors.primary, .purple], startPoint: .leading, endPoint: .trailing))
                                .cornerRadius(16)
                            }
                            .buttonStyle(SmoothButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                    } else {
                        ForEach(aiChallenges.activeChallenges) { challenge in
                            AIChallengeCard(challenge: challenge)
                        }
                        .padding(.horizontal, Design.Spacing.md)
                        
                        if !aiChallenges.completedChallenges.isEmpty {
                            VStack(alignment: .leading, spacing: Design.Spacing.sm) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Completed (\(aiChallenges.completedChallenges.count))")
                                        .font(Design.Typography.headline)
                                    Spacer()
                                }
                                .padding(.horizontal, Design.Spacing.md)
                                
                                ForEach(aiChallenges.completedChallenges.suffix(3)) { challenge in
                                    AIChallengeCard(challenge: challenge)
                                        .opacity(0.6)
                                }
                                .padding(.horizontal, Design.Spacing.md)
                            }
                        }
                        
                        Button {
                            Task { await aiChallenges.generateChallenges(forceRefresh: true) }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh Challenges")
                            }
                            .font(Design.Typography.subheadline)
                            .foregroundColor(Design.Colors.primary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Design.Colors.primary.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(SmoothButtonStyle())
                        .padding(.top, Design.Spacing.sm)
                    }
                }
            }
            .padding(.vertical, Design.Spacing.md)
        }
    }
    
    // MARK: - AI Challenge Header
    private var aiChallengeHeader: some View {
        VStack(spacing: Design.Spacing.md) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(LinearGradient(colors: [Design.Colors.primary, .purple], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                        .frame(width: 60, height: 60)
                    
                    VStack(spacing: 0) {
                        Text("\(aiChallenges.totalXPEarned)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Design.Colors.primary)
                        Text("XP")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("AI Challenges")
                            .font(Design.Typography.headline)
                        
                        Text("PRO")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(LinearGradient(colors: [Design.Colors.primary, .purple], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(6)
                    }
                    
                    Text("Personalized challenges based on your data")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("\u{1F525} \(aiChallenges.challengeStreak)")
                        .font(.headline)
                    Text("Streak")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Design.Spacing.md)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.04), radius: 6, x: 0, y: 2)
        .padding(.horizontal, Design.Spacing.md)
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
                    .foregroundColor(.primary)
                
                Text("Your personal AI coach analyzes your fitness data to create challenges that push you just beyond your comfort zone.")
                    .font(Design.Typography.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            
            VStack(alignment: .leading, spacing: 14) {
                PremiumFeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Adapts to your fitness level & habits", color: .green)
                PremiumFeatureRow(icon: "target", text: "Personalized daily & weekly targets", color: .orange)
                PremiumFeatureRow(icon: "star.fill", text: "Earn XP and unlock achievements", color: .yellow)
                PremiumFeatureRow(icon: "brain", text: "AI learns from your progress", color: .purple)
                PremiumFeatureRow(icon: "person.2.fill", text: "Share challenges with friends", color: .blue)
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
    
    // MARK: - Chats Section
    private var chatsSection: some View {
        ConversationsView()
    }
    
    // MARK: - Invite
    private var inviteShareText: String {
        let userId = auth.userId ?? ""
        let username = auth.name.isEmpty ? "a friend" : auth.name
        let deepLink = "gofitai://invite?from=\(userId)"
        return "Hey! \u{1F4AA} \(username) wants you to join GoFit.Ai \u{2014} the AI-powered fitness app. Track meals, compete with friends, and crush your goals together!\n\nJoin here: \(deepLink)\n\nOr search for @\(auth.name) in the app!"
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
        .shadow(color: Color.primary.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Search Result Row
struct SearchResultRow: View {
    let result: SearchResult
    let onAdd: (String) -> Void
    @State private var sendState: SendState = .idle
    
    enum SendState {
        case idle, sending, sent, failed
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(result.username.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(result.fullName ?? result.username)
                    .font(Design.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("@\(result.username)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if result.friendStatus == "friends" {
                Label("Friend", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else if result.friendStatus == "request_sent" || sendState == .sent {
                Label("Sent", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.green)
                    .transition(.scale.combined(with: .opacity))
            } else if sendState == .sending {
                ProgressView()
                    .frame(width: 40, height: 40)
            } else {
                Button {
                    sendState = .sending
                    HapticManager.shared.lightTap()
                    onAdd(result.id)
                    withAnimation(.spring(response: 0.3)) {
                        sendState = .sent
                    }
                } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.title3)
                        .foregroundColor(.white)
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
        .shadow(color: Color.primary.opacity(0.04), radius: 4, x: 0, y: 2)
        .animation(.easeInOut(duration: 0.2), value: sendState == .sent)
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
                // Search field
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Name, email, or username", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            friendsService.searchUsers(query: searchText) { _ in }
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            friendsService.searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, Design.Spacing.md)
                .padding(.top, Design.Spacing.sm)
                .onChange(of: searchText) { _, newValue in
                    guard newValue.count >= 2 else {
                        friendsService.searchResults = []
                        return
                    }
                    // Debounced live search
                    Task {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        guard searchText == newValue else { return }
                        friendsService.searchUsers(query: newValue) { _ in }
                    }
                }
                
                Divider().padding(.top, 12)
                
                // Results
                if friendsService.isLoading && friendsService.searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Searching...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else if friendsService.searchResults.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: searchText.count < 2 ? "person.badge.plus" : "magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(Design.Colors.primary.opacity(0.3))
                        
                        Text(searchText.count < 2 ? "Find friends by name or email" : "No results for \"\(searchText)\"")
                            .font(Design.Typography.body)
                            .foregroundColor(.secondary)
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
                
                // Invite share link at bottom
                ShareLink(
                    item: inviteText,
                    subject: Text("Join me on GoFit.Ai!"),
                    message: Text(inviteText)
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Invite via Link")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Design.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Design.Colors.primary.opacity(0.1))
                    .cornerRadius(14)
                }
                .padding(.horizontal, Design.Spacing.md)
                .padding(.bottom, Design.Spacing.md)
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isSearchFocused = true
                }
            }
        }
    }
    
    private var inviteText: String {
        let name = auth.name.isEmpty ? "Someone" : auth.name
        return "Hey! \u{1F4AA} \(name) wants you to join GoFit.Ai — the AI fitness app. Track meals, compete, and crush your goals together!\n\nDownload: https://apps.apple.com/app/gofit-ai"
    }
}

// MARK: - AI Challenge Card
struct AIChallengeCard: View {
    let challenge: AIChallenge
    
    var body: some View {
        VStack(spacing: Design.Spacing.md) {
            HStack(spacing: 12) {
                Text(challenge.icon)
                    .font(.title)
                    .frame(width: 50, height: 50)
                    .background(challenge.category.color.opacity(0.15))
                    .cornerRadius(14)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(challenge.title)
                            .font(Design.Typography.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 2) {
                            ForEach(0..<challenge.difficulty.stars, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(challenge.difficulty.color)
                            }
                        }
                    }
                    
                    Text(challenge.category.label)
                        .font(.caption2)
                        .foregroundColor(challenge.category.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(challenge.category.color.opacity(0.1))
                        .cornerRadius(6)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if challenge.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    } else {
                        Text("+\(challenge.xpReward) XP")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Design.Colors.primary)
                    }
                    
                    Text(challenge.timeRemainingText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(challenge.description)
                .font(Design.Typography.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 10)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: challenge.isCompleted ? [.green, .green] : [challenge.category.color, challenge.category.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * challenge.progressPercent, height: 10)
                            .animation(.easeInOut(duration: 0.3), value: challenge.progressPercent)
                    }
                }
                .frame(height: 10)
                
                HStack {
                    Text("\(Int(challenge.currentProgress))/\(Int(challenge.targetValue)) \(challenge.unit)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(challenge.progressPercent * 100))%")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(challenge.category.color)
                }
            }
        }
        .padding(Design.Spacing.md)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
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
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
                .frame(width: 32)
            
            Text(text)
                .font(Design.Typography.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}
