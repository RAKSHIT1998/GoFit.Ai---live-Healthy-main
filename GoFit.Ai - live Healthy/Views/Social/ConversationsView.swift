import SwiftUI

struct ConversationsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var messagesService = MessagesService.shared
    @ObservedObject private var webSocketService = WebSocketService.shared
    @ObservedObject private var friendsService = FriendsService.shared

    @State private var conversations: [ConversationSummary] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showUnreadOnly = false
    @State private var pinnedFriendIds: Set<String> = []
    @State private var mutedFriendIds: Set<String> = []
    @State private var isFetchingConversations = false
    @State private var refreshWorkItem: DispatchWorkItem?
    private let refreshTimer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

    private let pinnedStorageKey = "pinnedConversationFriendIds"
    private let mutedStorageKey = "mutedConversationFriendIds"

    private var filteredConversations: [ConversationSummary] {
        var result = conversations.sorted {
            let lhsPinned = pinnedFriendIds.contains($0.friendId)
            let rhsPinned = pinnedFriendIds.contains($1.friendId)
            if lhsPinned != rhsPinned {
                return lhsPinned && !rhsPinned
            }
            return ($0.lastMessageTime ?? .distantPast) > ($1.lastMessageTime ?? .distantPast)
        }
        if showUnreadOnly {
            result = result.filter { $0.unreadCount > 0 }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.friendName.localizedCaseInsensitiveContains(searchText) ||
                ($0.lastMessage ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    private var onlineFriends: [ConversationSummary] {
        conversations.filter { webSocketService.onlineUsers.contains($0.friendId) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search chats...", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, Design.Spacing.md)
            .padding(.top, 8)

            // Online friends stories row
            if !onlineFriends.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(onlineFriends, id: \.id) { convo in
                            NavigationLink {
                                ChatView(
                                    friend: Friend(
                                        id: convo.friendId,
                                        username: convo.friendName,
                                        email: "",
                                        fullName: convo.friendName,
                                        profileImageUrl: convo.friendImage
                                    ),
                                    currentUserId: auth.userId ?? ""
                                )
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [Design.Colors.primary, .green],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 2.5
                                            )
                                            .frame(width: 54, height: 54)

                                        avatarPlaceholder(name: convo.friendName)
                                            .frame(width: 46, height: 46)
                                    }

                                    Text(convo.friendName.components(separatedBy: " ").first ?? convo.friendName)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                                .frame(width: 60)
                            }
                        }
                    }
                    .padding(.horizontal, Design.Spacing.md)
                    .padding(.vertical, 10)
                }
            }

            // Filter toggle
            HStack {
                Button {
                    withAnimation { showUnreadOnly.toggle() }
                    HapticManager.shared.lightTap()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showUnreadOnly ? "envelope.badge.fill" : "envelope")
                            .font(.caption)
                        Text(showUnreadOnly ? "Unread" : "All")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(showUnreadOnly ? .white : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(showUnreadOnly ? Design.Colors.primary : Color.gray.opacity(0.08))
                    .clipShape(Capsule())
                }

                Spacer()

                Text("\(filteredConversations.count) chats")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, Design.Spacing.md)
            .padding(.vertical, 6)

            if isLoading && conversations.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.9)
                    Text("Loading conversations...")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else if conversations.isEmpty {
                if !friendsService.friends.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("No conversations yet.")
                            .font(.headline)
                            .padding(.horizontal, Design.Spacing.md)
                        Text("Start a conversation with your friends below.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, Design.Spacing.md)

                        ForEach(friendsService.friends, id: \.id) { friend in
                            NavigationLink {
                                ChatView(friend: friend, currentUserId: auth.userId ?? "")
                            } label: {
                                HStack(spacing: 12) {
                                    avatarPlaceholder(name: friend.username)
                                        .frame(width: 42, height: 42)

                                    VStack(alignment: .leading) {
                                        Text(friend.username).font(.body).fontWeight(.semibold)
                                        Text(friend.email).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text("Start")
                                        .font(.caption2).foregroundColor(Design.Colors.primary)
                                }
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal, Design.Spacing.md)
                            }
                        }

                    }
                    .padding(.top, 24)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48))
                            .foregroundColor(Design.Colors.primary.opacity(0.3))
                        Text("No conversations yet")
                            .font(Design.Typography.headline)
                        Text("Start a chat with a friend to see it here.")
                            .font(Design.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
                }
            } else if filteredConversations.isEmpty && !conversations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("No matching chats")
                        .font(Design.Typography.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 40)
            } else {
                List {
                    ForEach(Array(filteredConversations.enumerated()), id: \.element.id) { index, convo in
                            NavigationLink {
                                ChatView(
                                    friend: Friend(
                                        id: convo.friendId,
                                        username: convo.friendName,
                                        email: "",
                                        fullName: convo.friendName,
                                        profileImageUrl: convo.friendImage
                                    ),
                                    currentUserId: auth.userId ?? ""
                                )
                            } label: {
                                conversationRow(convo)
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    togglePin(friendId: convo.friendId)
                                } label: {
                                    Label(
                                        pinnedFriendIds.contains(convo.friendId) ? "Unpin" : "Pin",
                                        systemImage: pinnedFriendIds.contains(convo.friendId) ? "pin.slash.fill" : "pin.fill"
                                    )
                                }
                                .tint(.yellow)

                                Button {
                                    toggleMute(friendId: convo.friendId)
                                } label: {
                                    Label(
                                        mutedFriendIds.contains(convo.friendId) ? "Unmute" : "Mute",
                                        systemImage: mutedFriendIds.contains(convo.friendId) ? "bell.fill" : "bell.slash.fill"
                                    )
                                }
                                .tint(mutedFriendIds.contains(convo.friendId) ? .green : .orange)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await refreshConversations()
                    }
            }
        }
        .onAppear {
            loadChatPreferences()
            loadConversations()
        }
        .onChange(of: webSocketService.latestMessage) { oldMessage, newMessage in
            if let newMessage = newMessage {
                upsertConversationFromIncomingMessage(newMessage)
                scheduleBackgroundRefresh()
            }
            _ = oldMessage
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewMessageReceived"))) { _ in
            scheduleBackgroundRefresh()
        }
        .onReceive(refreshTimer) { _ in
            scheduleBackgroundRefresh()
        }
    }

    private func loadConversations() {
        guard !isFetchingConversations else { return }
        isFetchingConversations = true

        // Load from cache first for instant display
        let cached = SocialCacheManager.shared.cachedConversations
        if !cached.isEmpty && conversations.isEmpty {
            conversations = cached
            isLoading = false
        }
        
        // Then refresh from network in background
        messagesService.fetchConversations { result in
            DispatchQueue.main.async {
                self.isFetchingConversations = false
                isLoading = false
                if case .success(let items) = result {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        conversations = items
                    }
                    // Save to cache for next time
                    SocialCacheManager.shared.saveConversations(items)
                }
            }
        }
    }
    
    private func refreshConversations() async {
        guard !isFetchingConversations else { return }
        isFetchingConversations = true

        await withCheckedContinuation { continuation in
            messagesService.fetchConversations { result in
                DispatchQueue.main.async {
                    self.isFetchingConversations = false
                    if case .success(let items) = result {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            conversations = items
                        }
                    }
                    continuation.resume()
                }
            }
        }
    }

    private func conversationRow(_ convo: ConversationSummary) -> some View {
        let isOnline = webSocketService.onlineUsers.contains(convo.friendId)
        let isPinned = pinnedFriendIds.contains(convo.friendId)
        let isMuted = mutedFriendIds.contains(convo.friendId)
        
        return HStack(spacing: 12) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                if let imageUrl = convo.friendImage, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        default:
                            avatarPlaceholder(name: convo.friendName)
                        }
                    }
                } else {
                    avatarPlaceholder(name: convo.friendName)
                }
                
                if isOnline {
                    Circle()
                        .fill(.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle().stroke(Design.Colors.cardBackground, lineWidth: 2)
                        )
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(convo.friendName)
                        .font(Design.Typography.subheadline)
                        .fontWeight(convo.unreadCount > 0 ? .bold : .regular)
                        .foregroundColor(.primary)

                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }

                    if isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let date = convo.lastMessageTime {
                        Text(relativeTime(date))
                            .font(.caption2)
                            .foregroundColor(convo.unreadCount > 0 ? Design.Colors.primary : .secondary)
                    }
                }
                
                HStack {
                    if let last = convo.lastMessage {
                        Text(last)
                            .font(Design.Typography.caption)
                            .foregroundColor(convo.unreadCount > 0 ? .primary : .secondary)
                            .fontWeight(convo.unreadCount > 0 ? .medium : .regular)
                            .lineLimit(1)
                    } else {
                        Text("Tap to start chatting")
                            .font(Design.Typography.caption)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                    
                    Spacer()
                    
                    if convo.unreadCount > 0 {
                        Text("\(convo.unreadCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Design.Colors.primary)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(convo.unreadCount > 0 ? Design.Colors.primary.opacity(0.05) : Design.Colors.cardBackground)
        )
    }
    
    private func avatarPlaceholder(name: String) -> some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Design.Colors.primary.opacity(0.6), Design.Colors.primary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 50, height: 50)
            .overlay(
                Text(String(name.prefix(1)).uppercased())
                    .foregroundColor(.white)
                    .font(.headline)
                    .fontWeight(.bold)
            )
    }
    
    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 604800 { return "\(Int(interval / 86400))d" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private func loadChatPreferences() {
        let pinnedArray = UserDefaults.standard.stringArray(forKey: pinnedStorageKey) ?? []
        let mutedArray = UserDefaults.standard.stringArray(forKey: mutedStorageKey) ?? []
        pinnedFriendIds = Set(pinnedArray)
        mutedFriendIds = Set(mutedArray)
    }

    private func saveChatPreferences() {
        UserDefaults.standard.set(Array(pinnedFriendIds), forKey: pinnedStorageKey)
        UserDefaults.standard.set(Array(mutedFriendIds), forKey: mutedStorageKey)
    }

    private func togglePin(friendId: String) {
        if pinnedFriendIds.contains(friendId) {
            pinnedFriendIds.remove(friendId)
        } else {
            pinnedFriendIds.insert(friendId)
        }
        saveChatPreferences()
        HapticManager.shared.lightTap()
    }

    private func toggleMute(friendId: String) {
        if mutedFriendIds.contains(friendId) {
            mutedFriendIds.remove(friendId)
        } else {
            mutedFriendIds.insert(friendId)
        }
        saveChatPreferences()
        HapticManager.shared.lightTap()
    }

    private func upsertConversationFromIncomingMessage(_ message: MessageNotification) {
        if let existingIndex = conversations.firstIndex(where: { $0.friendId == message.senderId }) {
            let existing = conversations[existingIndex]
            let updated = ConversationSummary(
                friendId: existing.friendId,
                friendName: existing.friendName,
                friendImage: message.senderImage ?? existing.friendImage,
                lastMessage: message.message,
                lastMessageTime: message.timestamp,
                unreadCount: existing.unreadCount + 1,
                conversationId: message.conversationId
            )
            conversations[existingIndex] = updated
        } else {
            let newConversation = ConversationSummary(
                friendId: message.senderId,
                friendName: message.senderName,
                friendImage: message.senderImage,
                lastMessage: message.message,
                lastMessageTime: message.timestamp,
                unreadCount: 1,
                conversationId: message.conversationId
            )
            conversations.append(newConversation)
        }
    }

    private func scheduleBackgroundRefresh() {
        refreshWorkItem?.cancel()

        let workItem = DispatchWorkItem {
            loadConversations()
        }
        refreshWorkItem = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: workItem)
    }
}
