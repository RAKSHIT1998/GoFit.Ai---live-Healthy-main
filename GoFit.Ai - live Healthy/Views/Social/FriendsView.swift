import SwiftUI

struct FriendsView: View {
    @ObservedObject private var friendsService = FriendsService.shared
    @EnvironmentObject private var auth: AuthViewModel
    @State private var searchText = ""
    @State private var selectedTab: FriendsTab = .friends
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showInviteCopied = false
    @State private var autoShareBodyLogs = UserDefaults.standard.bool(forKey: "auto_share_body_logs_enabled")
    @State private var autoShareIntervalHours = FriendsService.shared.autoShareIntervalHours()
    
    enum FriendsTab {
        case friends
        case requests
        case search
        case conversations
    }
    
    var body: some View {
        ZStack {
            Design.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with stats
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Friends & Social")
                                .font(Design.Typography.headline)
                                .foregroundColor(.primary)
                            Text("\(friendsService.friends.count) friends connected")
                                .font(Design.Typography.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        HStack(spacing: 12) {
                            VStack(alignment: .center, spacing: 4) {
                                Text("\(friendsService.friendRequests.count)")
                                    .font(.headline)
                                    .foregroundColor(Design.Colors.primary)
                                Text("Requests")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Design.Colors.cardBackground)
                            .cornerRadius(12)

                            ShareLink(
                                item: inviteShareText,
                                subject: Text("Join me on GoFit.Ai!"),
                                message: Text(inviteShareText)
                            ) {
                                VStack(alignment: .center, spacing: 4) {
                                    Image(systemName: "person.badge.plus")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Invite")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Design.Colors.primary)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, Design.Spacing.md)
                    .padding(.vertical, Design.Spacing.md)

                    VStack(spacing: 10) {
                        Toggle(isOn: $autoShareBodyLogs) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Auto-share body progress")
                                    .font(Design.Typography.subheadline)
                                    .fontWeight(.semibold)
                                Text("Send weight updates to all friends when logged (24/7 mode)")
                                    .font(Design.Typography.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .onChange(of: autoShareBodyLogs) { oldValue, newValue in
                            FriendsService.shared.setAutoShareBodyLogEnabled(newValue)
                        }

                        HStack(spacing: 8) {
                            Text("Share interval:")
                                .font(Design.Typography.caption)
                                .foregroundColor(.secondary)
                            Picker("Hours", selection: $autoShareIntervalHours) {
                                ForEach([6, 12, 24], id: \ .self) { hour in
                                    Text("\(hour)h")
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: autoShareIntervalHours) { oldValue, newValue in
                                FriendsService.shared.setAutoShareInterval(hours: newValue)
                            }
                        }

                        Button(action: {
                            guard let latest = BodyLogManager.shared.entries.first else { return }
                            FriendsService.shared.shareBodyLogEntryToAllFriends(latest) { result in
                                switch result {
                                case .success(let count):
                                    errorMessage = "Shared log with \(count) friends"
                                case .failure(let error):
                                    errorMessage = error.localizedDescription
                                }
                                showError = true
                            }
                        }) {
                            Text("Share latest log now")
                                .font(Design.Typography.caption)
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(Design.Colors.primary.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    .padding(12)
                    .background(Design.Colors.cardBackground)
                    .cornerRadius(14)
                    .padding(.horizontal, Design.Spacing.md)
                    .padding(.bottom, 8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([FriendsTab.friends, .requests, .search, .conversations], id: \.self) { tab in
                                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab } }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: tabIcon(tab))
                                        Text(tabName(tab))
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(selectedTab == tab ? .white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == tab ? Design.Colors.primary : Design.Colors.cardBackground)
                                    .cornerRadius(10)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, Design.Spacing.md)
                    }
                }
                .background(Design.Colors.background)
                
                Divider()
                    .padding(.vertical, 8)
            
                ScrollView {
                    VStack(spacing: 0) {
                        switch selectedTab {
                        case .friends:
                            FriendsListView(friends: friendsService.friends, currentUserId: auth.userId ?? "")
                                .onAppear {
                                    friendsService.fetchFriends { _ in }
                                }
                            
                        case .requests:
                            FriendRequestsView(
                                requests: friendsService.friendRequests,
                                onAccept: { friendId in
                                    friendsService.acceptFriendRequest(from: friendId) { _ in
                                        friendsService.fetchFriendRequests { _ in }
                                        friendsService.fetchFriends { _ in }
                                    }
                                },
                                onDecline: { friendId in
                                    friendsService.rejectFriendRequest(from: friendId) { _ in
                                        friendsService.fetchFriendRequests { _ in }
                                    }
                                }
                            )
                            .onAppear {
                                friendsService.fetchFriendRequests { _ in }
                            }
                            
                        case .search:
                            SearchFriendsView(
                                searchText: $searchText,
                                searchResults: friendsService.searchResults,
                                isLoading: friendsService.isLoading,
                                onSearch: { query in
                                    guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
                                        friendsService.searchResults = []
                                        return
                                    }
                                    friendsService.searchUsers(query: query) { _ in }
                                },
                                onAddFriend: { userId in
                                    friendsService.sendFriendRequest(to: userId) { result in
                                        DispatchQueue.main.async {
                                            if case .success(let message) = result {
                                                errorMessage = message
                                                showError = true
                                                friendsService.searchResults.removeAll { $0.id == userId }
                                                searchText = ""
                                            } else {
                                                errorMessage = "Failed to send request"
                                                showError = true
                                            }
                                        }
                                    }
                                }
                            )
                        case .conversations:
                            ConversationsView()
                        }
                    }
                    .padding(.vertical, Design.Spacing.md)
                }
                
                Spacer()
            }
            .alert(errorMessage.lowercased().contains("fail") || errorMessage.lowercased().contains("error") ? "Error" : "Success", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .onAppear {
            friendsService.fetchFriends { _ in }
            autoShareBodyLogs = FriendsService.shared.isAutoShareBodyLogEnabled()
            autoShareIntervalHours = FriendsService.shared.autoShareIntervalHours()
        }
    }
    
    private func tabName(_ tab: FriendsTab) -> String {
        switch tab {
        case .friends: return "Friends"
        case .requests: return "Requests"
        case .search: return "Search"
        case .conversations: return "Chats"
        }
    }
    
    private func tabIcon(_ tab: FriendsTab) -> String {
        switch tab {
        case .friends: return "person.2"
        case .requests: return "envelope"
        case .search: return "magnifyingglass"
        case .conversations: return "bubble.left.and.bubble.right"
        }
    }

    private var inviteShareText: String {
        let userId = auth.userId ?? ""
        let username = auth.name.isEmpty ? "a friend" : auth.name
        let deepLink = "gofitai://invite?from=\(userId)"
        return "Hey! \u{1F4AA} \(username) wants you to join GoFit.Ai \u{2014} the AI-powered fitness app. Track meals, compete with friends, and crush your goals together!\n\nJoin here: \(deepLink)\n\nOr search for @\(auth.name) in the app!"
    }
}

// MARK: - Friends List View
struct FriendsListView: View {
    let friends: [Friend]
    let currentUserId: String
    
    var body: some View {
        if friends.isEmpty {
            VStack(spacing: 24) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 64))
                    .foregroundColor(Design.Colors.primary.opacity(0.3))
                
                VStack(spacing: 8) {
                    Text("No Friends Yet")
                        .font(Design.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Text("Add friends to share your fitness journey and compete together!")
                        .font(Design.Typography.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, Design.Spacing.lg)
        } else {
            VStack(spacing: Design.Spacing.md) {
                ForEach(friends, id: \.id) { friend in
                    FriendCardView(friend: friend, currentUserId: currentUserId)
                }
            }
            .padding(.horizontal, Design.Spacing.md)
        }
    }
}

// MARK: - Friend Card View
struct FriendCardView: View {
    let friend: Friend
    let currentUserId: String
    @State private var cheerSent = false
    @State private var isSendingCheer = false
    @State private var showCheerBurst = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Header: tapping navigates to friend details
            NavigationLink(destination: FriendDetailsView(friend: friend, currentUserId: currentUserId)) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(LinearGradient(gradient: Gradient(colors: [Design.Colors.primary.opacity(0.7), Design.Colors.primary.opacity(0.4)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Text(String(friend.username.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(friend.fullName ?? friend.username)
                            .font(Design.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("@\(friend.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            
            Divider()
                .padding(.vertical, 4)
            
            HStack(spacing: 12) {
                // Cheer button - sends a random cheer message
                Button(action: sendCheer) {
                    HStack(spacing: 4) {
                        Image(systemName: cheerSent ? "heart.fill" : "heart")
                            .foregroundColor(cheerSent ? .red : Design.Colors.primary)
                            .scaleEffect(showCheerBurst ? 1.4 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.4), value: showCheerBurst)
                        Text(cheerSent ? "Sent! 🎉" : "Cheer")
                    }
                    .font(.caption)
                    .fontWeight(cheerSent ? .bold : .regular)
                    .foregroundColor(cheerSent ? .red : Design.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(cheerSent ? Color.red.opacity(0.1) : Design.Colors.primary.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(isSendingCheer)
                .buttonStyle(.borderless)
                
                // Message button - navigates to chat
                NavigationLink(destination: ChatView(friend: friend, currentUserId: currentUserId)) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        Text("Message")
                    }
                    .font(.caption)
                    .foregroundColor(Design.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Design.Colors.primary.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(Design.Spacing.md)
        .background(Design.Colors.cardBackground)
        .cornerRadius(Design.Radius.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func sendCheer() {
        guard !isSendingCheer else { return }
        isSendingCheer = true
        HapticManager.shared.mediumTap()
        
        let cheerMessage = ViralEngagementManager.randomCheerMessage()
        
        MessagesService.shared.sendMessage(friendId: friend.id, message: cheerMessage) { result in
            DispatchQueue.main.async {
                isSendingCheer = false
                if case .success = result {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        cheerSent = true
                        showCheerBurst = true
                    }
                    HapticManager.shared.success()
                    
                    // Reset burst animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showCheerBurst = false
                    }
                    
                    // Reset after 3 seconds so user can cheer again
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { cheerSent = false }
                    }
                } else {
                    HapticManager.shared.error()
                }
            }
        }
    }
}

// MARK: - Friend Requests View
struct FriendRequestsView: View {
    let requests: [FriendRequest]
    let onAccept: (String) -> Void
    let onDecline: (String) -> Void
    
    var body: some View {
        if requests.isEmpty {
            VStack(spacing: 24) {
                Image(systemName: "envelope.open")
                    .font(.system(size: 64))
                    .foregroundColor(Design.Colors.primary.opacity(0.3))
                
                VStack(spacing: 8) {
                    Text("All Caught Up!")
                        .font(Design.Typography.headline)
                        .foregroundColor(.primary)
                    
                    Text("You don't have any pending friend requests")
                        .font(Design.Typography.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, Design.Spacing.lg)
        } else {
            VStack(spacing: Design.Spacing.md) {
                ForEach(requests, id: \.id) { request in
                    FriendRequestCardView(request: request, onAccept: { onAccept(request.requesterId) }, onDecline: { onDecline(request.requesterId) })
                }
            }
            .padding(.horizontal, Design.Spacing.md)
        }
    }
}

// MARK: - Friend Request Card View
struct FriendRequestCardView: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var showDeclineConfirm = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.orange.opacity(0.7), Color.yellow.opacity(0.5)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(String(request.requesterUsername.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(request.requesterFullName ?? request.requesterUsername)
                        .font(Design.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("@\(request.requesterUsername)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "hand.raised.fill")
                            .font(.caption2)
                            .foregroundColor(Design.Colors.primary)
                        Text("Wants to connect")
                            .font(.caption2)
                            .foregroundColor(Design.Colors.primary)
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(action: { showDeclineConfirm = true }) {
                    Text("Decline")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Button(action: onAccept) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Accept")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Design.Colors.primary)
                    .cornerRadius(8)
                }
            }
        }
        .padding(Design.Spacing.md)
        .background(Design.Colors.cardBackground)
        .cornerRadius(Design.Radius.medium)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .confirmationDialog("Decline Request", isPresented: $showDeclineConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Decline", role: .destructive) { onDecline() }
        } message: {
            Text("Are you sure you want to decline this friend request?")
        }
    }
}

// MARK: - Search Friends View
struct SearchFriendsView: View {
    @Binding var searchText: String
    let searchResults: [SearchResult]
    let isLoading: Bool
    let onSearch: (String) -> Void
    let onAddFriend: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                SearchBar(text: $searchText, placeholder: "Search by email, name, or username", onSearch: onSearch)
                
                if searchText.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Type an email, username, or name to find and add friends")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 4)
                }
            }
            .padding()
            
            if isLoading {
                VStack {
                    ProgressView()
                    Text("Searching...")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            } else if searchResults.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    VStack(spacing: 8) {
                        Text(searchText.isEmpty ? "Find Friends" : "No results found")
                            .font(.headline)
                        
                        if !searchText.isEmpty {
                            Text("Try searching by email or full name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .padding()
            } else {
                List {
                    ForEach(searchResults, id: \.id) { result in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)]), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Text(String(result.username.prefix(1)).uppercased())
                                        .font(.headline)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(result.fullName ?? result.username)
                                    .font(.headline)
                                
                                Text("@\(result.username)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if result.friendStatus == "friends" {
                                Label("Friend", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            } else if result.friendStatus == "request_sent" {
                                Label("Sent", systemImage: "clock.badge")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Button(action: { onAddFriend(result.id) }) {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                        .padding(8)
                                        .contentShape(Rectangle())
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

// MARK: - Friend Details View
struct FriendDetailsView: View {
    let friend: Friend
    let currentUserId: String
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var friendsService = FriendsService.shared
    @State private var friendStats: FriendStats?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(friend.username.prefix(1)))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                Text(friend.fullName ?? friend.username)
                    .font(.headline)
                
                Text(friend.email)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            if let stats = friendStats {
                VStack(spacing: 12) {
                    StatRowItem(label: "Workouts", value: "\(stats.totalWorkoutsCompleted)")
                    StatRowItem(label: "Meals Logged", value: "\(stats.totalMealsLogged)")
                    StatRowItem(label: "Calories Burned", value: "\(stats.totalCaloriesBurned)")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading stats...")
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }

            HStack(spacing: 12) {
                NavigationLink(destination: ChatView(friend: friend, currentUserId: auth.userId ?? "")) {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.right.fill")
                        Text("Message")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Design.Colors.primary)
                    .cornerRadius(10)
                }

                NavigationLink(destination: ChatView(friend: friend, currentUserId: auth.userId ?? "")) {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                        Text("Share Log")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Design.Colors.primary)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Design.Colors.primary.opacity(0.1))
                    .cornerRadius(10)
                }
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Friend Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            friendsService.getFriendStats(friendId: friend.id) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    if case .success(let stats) = result {
                        friendStats = stats
                    }
                }
            }
        }
    }
}

struct StatRowItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.headline)
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onSearch: (String) -> Void
    @FocusState private var isFocused: Bool
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit { onSearch(text) }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onSearch("")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onChange(of: text) { _, newValue in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run { onSearch(newValue) }
            }
        }
    }
    
    func autoFocus() -> some View {
        self.onAppear { isFocused = true }
    }
}

#Preview {
    FriendsView()
}
