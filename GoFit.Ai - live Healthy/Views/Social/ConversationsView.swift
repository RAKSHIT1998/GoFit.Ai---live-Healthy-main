import SwiftUI

struct ConversationsView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @StateObject private var messagesService = MessagesService.shared
    @ObservedObject private var webSocketService = WebSocketService.shared

    @State private var conversations: [ConversationSummary] = []
    @State private var isLoading = true
    @State private var isRefreshing = false

    var body: some View {
        VStack(spacing: 0) {
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
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(conversations.enumerated()), id: \.element.id) { index, convo in
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
                        }
                    }
                    .padding(.horizontal, Design.Spacing.md)
                    .padding(.top, 8)
                }
                .refreshable {
                    await refreshConversations()
                }
            }
        }
        .onAppear {
            loadConversations()
        }
        .onChange(of: webSocketService.latestMessage) { _, _ in
            loadConversations()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewMessageReceived"))) { _ in
            loadConversations()
        }
    }

    private func loadConversations() {
        // Load from cache first for instant display
        let cached = SocialCacheManager.shared.cachedConversations
        if !cached.isEmpty && conversations.isEmpty {
            conversations = cached
            isLoading = false
        }
        
        // Then refresh from network in background
        messagesService.fetchConversations { result in
            DispatchQueue.main.async {
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
        await withCheckedContinuation { continuation in
            messagesService.fetchConversations { result in
                DispatchQueue.main.async {
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
}
