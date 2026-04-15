import SwiftUI

struct ChatView: View {
    let friend: Friend
    let currentUserId: String

    @StateObject private var messagesService = MessagesService.shared
    @ObservedObject private var webSocketService = WebSocketService.shared
    @ObservedObject private var cache = UserDataCache.shared

    @State private var messages: [MessageItem] = []
    @State private var messageText = ""
    @State private var isSending = false
    @State private var isLoadingMessages = true
    @State private var replyingTo: MessageItem? = nil
    @State private var showReactionPicker: String? = nil
    @State private var reactions: [String: [String]] = [:]  // messageId -> [emoji]
    @State private var isTyping = false
    @State private var typingTimer: Timer?
    @State private var hasNotifiedTyping = false
    @FocusState private var isTextFieldFocused: Bool
    private let refreshTimer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Online status indicator
            if webSocketService.onlineUsers.contains(friend.id) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("Online")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.08))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    if isLoadingMessages {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading messages...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else if messages.isEmpty {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 40)

                            ZStack {
                                Circle()
                                    .fill(Design.Colors.primary.opacity(0.08))
                                    .frame(width: 100, height: 100)
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(
                                        LinearGradient(colors: [Design.Colors.primary, .purple],
                                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            }

                            Text("Start the conversation!")
                                .font(Design.Typography.headline)
                                .foregroundColor(.primary)

                            Text("Say hello to \(friend.fullName ?? friend.username) \u{1F44B}")
                                .font(Design.Typography.caption)
                                .foregroundColor(.secondary)

                            Button {
                                messageText = "Hey! \u{1F44B}"
                                isTextFieldFocused = true
                            } label: {
                                Text("Wave \u{1F44B}")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Design.Colors.primary)
                                    .cornerRadius(20)
                            }
                            .buttonStyle(SmoothButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                                let showTimestamp = shouldShowTimestamp(at: index)
                                
                                if showTimestamp {
                                    Text(formatDateSection(msg.createdAt))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 8)
                                }
                                
                                messageBubble(msg)
                                    .id(msg.id)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                                        removal: .opacity
                                    ))
                                    .onLongPressGesture {
                                        withAnimation(.spring(response: 0.3)) {
                                            showReactionPicker = showReactionPicker == msg.id ? nil : msg.id
                                        }
                                        HapticManager.shared.mediumTap()
                                    }
                                    .overlay(alignment: msg.senderId == currentUserId ? .topLeading : .topTrailing) {
                                        if showReactionPicker == msg.id {
                                            reactionPickerOverlay(for: msg)
                                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                                        }
                                    }
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
                .onChange(of: messages.count) { oldCount, newCount in
                    withAnimation(.easeOut(duration: 0.3)) {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                    _ = oldCount
                    _ = newCount
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            .onTapGesture {
                isTextFieldFocused = false
            }

            Divider()

            // Reply banner
            if let reply = replyingTo {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Design.Colors.primary)
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(reply.senderId == currentUserId ? "You" : reply.senderName)
                            .font(.caption.bold())
                            .foregroundColor(Design.Colors.primary)
                        Text(reply.message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        withAnimation { replyingTo = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Design.Colors.cardBackground)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Typing indicator
            if isTyping {
                HStack(spacing: 4) {
                    Text("\(friend.fullName ?? friend.username) is typing")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(Color.secondary)
                                .frame(width: 4, height: 4)
                                .opacity(0.6)
                                .animation(.easeInOut(duration: 0.5).repeatForever(), value: isTyping)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .transition(.opacity)
            }

            // Input bar
            HStack(spacing: 8) {
                Button {
                    sendTodaySummary()
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Design.Colors.primary)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Share today's summary")
                .scaleEffect(isSending ? 0.9 : 1.0)
                .animation(.spring(response: 0.2), value: isSending)

                TextField("Message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($isTextFieldFocused)
                    .onChange(of: messageText) { _, newValue in
                        handleTypingInput(newValue)
                    }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: isSending ? "ellipsis" : "paperplane.fill")
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : Design.Colors.primary)
                        .symbolEffect(.pulse, isActive: isSending)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .scaleEffect(isSending ? 0.8 : 1.0)
                .animation(.spring(response: 0.2), value: isSending)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Design.Colors.cardBackground)
        }
        .navigationTitle(friend.fullName ?? friend.username)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            WebSocketService.shared.currentChatFriendId = friend.id
            loadMessages()
            markConversationAsRead()
            observeTypingStatus()
        }
        .onDisappear {
            if WebSocketService.shared.currentChatFriendId == friend.id {
                WebSocketService.shared.currentChatFriendId = nil
                webSocketService.sendTypingIndicator(to: friend.id, isTyping: false)
            }
            typingTimer?.invalidate()
        }
        .onChange(of: webSocketService.typingStatus) { _, newStatus in
            isTyping = newStatus[friend.id] ?? false
        }
        .onChange(of: webSocketService.latestMessage) { _, newValue in
            guard let message = newValue, message.senderId == friend.id else { return }

            let item = MessageItem(
                id: message.messageId,
                senderId: message.senderId,
                senderName: message.senderName,
                senderImage: message.senderImage,
                message: message.message,
                messageType: message.messageType,
                isRead: false,
                createdAt: message.timestamp
            )
            appendMessageIfNeeded(item)
            HapticManager.shared.lightTap()
        }
        .onReceive(refreshTimer) { _ in
            refreshMessagesSilently()
        }
    }

    private func messageBubble(_ msg: MessageItem) -> some View {
        let isMine = msg.senderId == currentUserId
        let isSummaryMessage = msg.message.hasPrefix("📊")
        let isCheerMessage = msg.message.contains("🎉👏") || msg.message.contains("Cheering you") || msg.message.contains("Beast mode") || msg.message.contains("crushing it")
        
        return HStack(alignment: .bottom, spacing: 6) {
            if isMine { Spacer(minLength: 50) }
            
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                if isSummaryMessage {
                    // Animated summary card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(.yellow)
                            Text("Fitness Summary")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "sparkles")
                                .foregroundColor(.yellow)
                                .symbolEffect(.pulse)
                        }
                        
                        ForEach(msg.message.components(separatedBy: "\n"), id: \.self) { line in
                            if !line.hasPrefix("📊") {
                                Text(line)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.95))
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        LinearGradient(
                            colors: [Color.purple, Color.blue, Color.indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                } else if isCheerMessage {
                    // Animated cheer message
                    VStack(spacing: 4) {
                        Text(msg.message)
                            .font(Design.Typography.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(isMine ? .trailing : .leading)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.red, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .orange.opacity(0.3), radius: 6, x: 0, y: 3)
                } else {
                    Text(msg.message)
                        .font(Design.Typography.body)
                        .foregroundColor(isMine ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Group {
                                if isMine {
                                    Design.Colors.primaryGradient
                                } else {
                                    LinearGradient(colors: [Color(.systemGray6)], startPoint: .leading, endPoint: .trailing)
                                }
                            }
                        )
                        .cornerRadius(16, corners: isMine ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                }
                
                HStack(spacing: 4) {
                    Text(formatTime(msg.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(isMine ? .secondary : .secondary)
                    
                    if isMine {
                        Image(systemName: msg.isRead ? "checkmark.checkmark" : "checkmark")
                            .font(.system(size: 10))
                            .foregroundColor(msg.isRead ? .blue : .secondary)
                    }
                }

                reactionsRow(for: msg.id)
            }
            
            if !isMine { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            withAnimation { replyingTo = msg }
            HapticManager.shared.lightTap()
        }
    }
    
    // MARK: - Reaction Picker
    private func reactionPickerOverlay(for msg: MessageItem) -> some View {
        HStack(spacing: 6) {
            ForEach(["\u{1F525}", "\u{2764}\u{FE0F}", "\u{1F44D}", "\u{1F602}", "\u{1F622}", "\u{1F64F}"], id: \.self) { emoji in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        var current = reactions[msg.id] ?? []
                        if current.contains(emoji) {
                            current.removeAll { $0 == emoji }
                        } else {
                            current.append(emoji)
                        }
                        reactions[msg.id] = current
                        showReactionPicker = nil
                    }
                    HapticManager.shared.lightTap()
                } label: {
                    Text(emoji)
                        .font(.system(size: 20))
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
        .offset(y: -10)
    }

    private func reactionsRow(for msgId: String) -> some View {
        Group {
            if let msgReactions = reactions[msgId], !msgReactions.isEmpty {
                HStack(spacing: 2) {
                    ForEach(msgReactions, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 14))
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
            }
        }
    }

    private func shouldShowTimestamp(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = messages[index].createdAt
        let previous = messages[index - 1].createdAt
        return current.timeIntervalSince(previous) > 300 // 5 minute gap
    }

    private func loadMessages() {
        isLoadingMessages = true
        
        // Load from cache first for instant display
        if let cached = SocialCacheManager.shared.loadMessages(for: friend.id), !cached.isEmpty {
            self.messages = cached
            isLoadingMessages = false
        }
        
        // Then refresh from network
        messagesService.fetchConversation(friendId: friend.id) { result in
            DispatchQueue.main.async {
                isLoadingMessages = false
                if case .success(let msgs) = result {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.messages = msgs
                    }
                    // Save to cache for next time
                    SocialCacheManager.shared.saveMessages(msgs, for: friend.id)
                }
            }
        }
    }

    private func refreshMessagesSilently() {
        messagesService.fetchConversation(friendId: friend.id) { result in
            DispatchQueue.main.async {
                guard case .success(let msgs) = result else { return }
                self.messages = msgs
                SocialCacheManager.shared.saveMessages(msgs, for: friend.id)
            }
        }
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true

        // Build message with reply prefix if replying
        var textToSend = trimmed
        if let reply = replyingTo {
            let replyName = reply.senderId == currentUserId ? "You" : reply.senderName
            let shortQuote = String(reply.message.prefix(60))
            textToSend = "[\u{21A9}\u{FE0F} \(replyName): \(shortQuote)]\n\(trimmed)"
        }

        messageText = ""
        let savedReply = replyingTo
        withAnimation { replyingTo = nil }
        
        messagesService.sendMessage(friendId: friend.id, message: textToSend) { result in
            DispatchQueue.main.async {
                isSending = false
                if case .success(let msg) = result {
                    appendMessageIfNeeded(msg)
                    HapticManager.shared.lightTap()
                } else {
                    // Put text back if send failed
                    messageText = trimmed
                    replyingTo = savedReply
                    HapticManager.shared.warning()
                }
            }
        }
    }

    private func sendTodaySummary() {
        // Force refresh from all local data sources
        let broadcaster = NutritionBroadcaster.shared
        broadcaster.refreshFromLocalStorage()
        
        // Also pull from every available source for maximum accuracy
        let todayLog = LocalDailyLogStore.shared.getTodayLog()
        let mealCacheTotals = LocalMealCache.shared.getTodayTotals()
        let fallbackStats = cache.calculateTodaysStats()
        
        // Use the BEST data from all 3 sources (whichever has the highest real value)
        let calories = max(todayLog.totalCalories, max(mealCacheTotals.calories, fallbackStats.totalCaloriesConsumed))
        let protein = max(todayLog.totalProtein, max(mealCacheTotals.protein, fallbackStats.protein))
        let carbs = max(todayLog.totalCarbs, max(mealCacheTotals.carbs, fallbackStats.carbs))
        let fat = max(todayLog.totalFat, max(mealCacheTotals.fat, fallbackStats.fat))
        let workouts = fallbackStats.workoutsCompleted
        let mealsLogged = max(todayLog.meals.count, max(LocalMealCache.shared.getTodayMeals().count, fallbackStats.mealsLogged))
        let water = max(todayLog.totalLiquid, fallbackStats.waterIntake)
        let steps = todayLog.steps ?? fallbackStats.steps
        let burned = max(todayLog.caloriesBurned, fallbackStats.totalCaloriesBurned)

        let waterStr = String(format: "%.1f", water)
        let summary = "📊 Today's GoFit Stats:\n🔥 \(Int(calories)) kcal consumed\n💪 P: \(Int(protein))g | C: \(Int(carbs))g | F: \(Int(fat))g\n⚡️ \(Int(burned)) kcal burned\n🏃 Workouts: \(workouts)\n🍽️ Meals: \(mealsLogged)\n💧 Water: \(waterStr)L\n🚶 Steps: \(steps)"
        isSending = true
        messagesService.sendMessage(friendId: friend.id, message: summary) { result in
            DispatchQueue.main.async {
                isSending = false
                if case .success(let msg) = result {
                    appendMessageIfNeeded(msg)
                    HapticManager.shared.success()
                }
            }
        }
    }

    private func appendMessageIfNeeded(_ msg: MessageItem) {
        guard !messages.contains(where: { $0.id == msg.id }) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            messages.append(msg)
        }
    }
    
    private func handleTypingInput(_ text: String) {
        let isEmpty = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        if !isEmpty && !hasNotifiedTyping {
            hasNotifiedTyping = true
            webSocketService.sendTypingIndicator(to: friend.id, isTyping: true)
        }
        
        typingTimer?.invalidate()
        let friendId = friend.id
        let webSocket = webSocketService
        typingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
            self.hasNotifiedTyping = false
            webSocket.sendTypingIndicator(to: friendId, isTyping: false)
        }
    }
    
    private func markConversationAsRead() {
        for msg in messages where msg.senderId != currentUserId && !msg.isRead {
            webSocketService.sendReadReceipt(for: msg.id, conversationId: msg.id)
        }
    }
    
    private func observeTypingStatus() {
        isTyping = webSocketService.typingStatus[friend.id] ?? false
    }


    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDateSection(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
