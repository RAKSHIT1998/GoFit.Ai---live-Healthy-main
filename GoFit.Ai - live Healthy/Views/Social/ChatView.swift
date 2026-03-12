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
    @State private var showSentConfirmation = false
    @FocusState private var isTextFieldFocused: Bool

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
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40))
                                .foregroundColor(Design.Colors.primary.opacity(0.3))
                            Text("No messages yet")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Say hello to \(friend.fullName ?? friend.username)!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
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
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
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
            loadMessages()
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
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                messages.append(item)
            }
            HapticManager.shared.lightTap()
        }
    }

    private func messageBubble(_ msg: MessageItem) -> some View {
        let isMine = msg.senderId == currentUserId
        return HStack(alignment: .bottom, spacing: 6) {
            if isMine { Spacer(minLength: 50) }
            
            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                Text(msg.message)
                    .font(Design.Typography.body)
                    .foregroundColor(isMine ? .white : .primary)
                
                HStack(spacing: 4) {
                    Text(formatTime(msg.createdAt))
                        .font(.system(size: 10))
                        .foregroundColor(isMine ? .white.opacity(0.6) : .secondary)
                    
                    if isMine {
                        Image(systemName: msg.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(isMine ? .white.opacity(0.6) : .secondary)
                    }
                }
            }
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
            
            if !isMine { Spacer(minLength: 50) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
    }
    
    private func shouldShowTimestamp(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let current = messages[index].createdAt
        let previous = messages[index - 1].createdAt
        return current.timeIntervalSince(previous) > 300 // 5 minute gap
    }

    private func loadMessages() {
        isLoadingMessages = true
        messagesService.fetchConversation(friendId: friend.id) { result in
            DispatchQueue.main.async {
                isLoadingMessages = false
                if case .success(let msgs) = result {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.messages = msgs
                    }
                }
            }
        }
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        let textToSend = trimmed
        messageText = "" // Clear immediately for responsive feel
        
        messagesService.sendMessage(friendId: friend.id, message: textToSend) { result in
            DispatchQueue.main.async {
                isSending = false
                if case .success(let msg) = result {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        messages.append(msg)
                    }
                    HapticManager.shared.lightTap()
                } else {
                    // Put text back if send failed
                    messageText = textToSend
                    HapticManager.shared.warning()
                }
            }
        }
    }

    private func sendTodaySummary() {
        let todayLog = LocalDailyLogStore.shared.getTodayLog()
        let fallbackStats = cache.calculateTodaysStats()

        let calories = todayLog.totalCalories > 0 ? todayLog.totalCalories : fallbackStats.totalCaloriesConsumed
        let protein = todayLog.totalProtein > 0 ? todayLog.totalProtein : fallbackStats.protein
        let carbs = todayLog.totalCarbs > 0 ? todayLog.totalCarbs : fallbackStats.carbs
        let fat = todayLog.totalFat > 0 ? todayLog.totalFat : fallbackStats.fat
        let workouts = fallbackStats.workoutsCompleted
        let mealsLogged = todayLog.meals.count > 0 ? todayLog.meals.count : fallbackStats.mealsLogged
        let water = todayLog.totalLiquid > 0 ? todayLog.totalLiquid : fallbackStats.waterIntake
        let steps = todayLog.steps ?? fallbackStats.steps

        let summary = "📊 Today: \(Int(calories)) kcal, P \(Int(protein))g, C \(Int(carbs))g, F \(Int(fat))g, Workouts \(workouts), Meals \(mealsLogged), Water \(String(format: \"%.1f\", water))L, Steps \(steps)"
        isSending = true
        messagesService.sendMessage(friendId: friend.id, message: summary) { result in
            DispatchQueue.main.async {
                isSending = false
                if case .success(let msg) = result {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        messages.append(msg)
                    }
                    HapticManager.shared.success()
                }
            }
        }
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