import Foundation
import UserNotifications
import UIKit

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var notificationsEnabled: Bool = true  // DEFAULT: ON
    @Published var mealRemindersEnabled: Bool = true
    @Published var waterRemindersEnabled: Bool = true
    @Published var workoutRemindersEnabled: Bool = true
    
    private init() {
        loadSettings()
        // Auto-request authorization on first launch (silent request)
        checkAuthorizationStatusAndSchedule()
        // Auto-request if not yet authorized
        requestAuthorizationIfNeeded()
    }
    
    // MARK: - Authorization
    
    /// Silently request authorization on app launch if needed
    private func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                guard let self = self else { return }
                
                // If not determined yet, request permission
                if settings.authorizationStatus == .notDetermined {
                    print("📢 First launch - requesting notification permissions...")
                    self.requestAuthorization()
                }
            }
        }
    }
    
    /// User explicitly requests notifications (from button tap)
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.notificationsEnabled = granted
                // Persist the actual authorization result to UserDefaults
                self.saveSettings()
                if granted {
                    print("✅ Notification permission granted")
                    self.scheduleAllNotifications()
                } else {
                    print("❌ Notification permission denied")
                }
                if let error = error {
                    print("⚠️ Notification authorization error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // Check authorization status and schedule notifications if already authorized
    private func checkAuthorizationStatusAndSchedule() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                guard let self = self else { return }
                let wasAuthorized = self.notificationsEnabled
                self.notificationsEnabled = settings.authorizationStatus == .authorized
                
                if self.notificationsEnabled && !wasAuthorized {
                    self.scheduleAllNotifications()
                } else if !self.notificationsEnabled && wasAuthorized {
                    // Permission was revoked, clear notifications
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                }
            }
        }
    }
    
    /// Enable ALL notifications (called from settings)
    func enableAllNotifications() {
        notificationsEnabled = true
        mealRemindersEnabled = true
        waterRemindersEnabled = true
        workoutRemindersEnabled = true
        saveSettings()
        scheduleAllNotifications()
    }
    
    /// Disable ALL notifications (called from settings)
    func disableAllNotifications() {
        notificationsEnabled = false
        mealRemindersEnabled = false
        waterRemindersEnabled = false
        workoutRemindersEnabled = false
        saveSettings()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Settings
    
    private func loadSettings() {
        // Load with proper defaults
        // If never set, all default to true (notifications active)
        let hasLoadedBefore = UserDefaults.standard.object(forKey: "gofit_notif_initialized") != nil
        
        if !hasLoadedBefore {
            // First time - enable all notifications by default
            UserDefaults.standard.set(true, forKey: "gofit_notif_initialized")
            notificationsEnabled = true
            mealRemindersEnabled = true
            waterRemindersEnabled = true
            workoutRemindersEnabled = true
            saveSettings()
        } else {
            // Load saved preferences
            notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
            mealRemindersEnabled = UserDefaults.standard.object(forKey: "mealRemindersEnabled") as? Bool ?? true
            waterRemindersEnabled = UserDefaults.standard.object(forKey: "waterRemindersEnabled") as? Bool ?? true
            workoutRemindersEnabled = UserDefaults.standard.object(forKey: "workoutRemindersEnabled") as? Bool ?? true
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        UserDefaults.standard.set(mealRemindersEnabled, forKey: "mealRemindersEnabled")
        UserDefaults.standard.set(waterRemindersEnabled, forKey: "waterRemindersEnabled")
        UserDefaults.standard.set(workoutRemindersEnabled, forKey: "workoutRemindersEnabled")
        // Synchronize to ensure immediate persistence
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Schedule Notifications
    
    func scheduleAllNotifications() {
        guard notificationsEnabled else { return }
        
        // Cancel all existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        if mealRemindersEnabled {
            scheduleMealReminders()
        }
        
        if waterRemindersEnabled {
            scheduleWaterReminders()
        }
        
        if workoutRemindersEnabled {
            scheduleWorkoutReminders()
        }
        
        // Always schedule social engagement notifications for retention
        scheduleSocialEngagementNotifications()
        
        // Schedule daily motivational notification
        scheduleDailyMotivation()
    }
    
    // MARK: - Meal Reminders
    
    private func scheduleMealReminders() {
        // Breakfast: 8:00 AM
        scheduleMealReminder(hour: 8, minute: 0, mealType: "breakfast", identifier: "meal-breakfast")
        
        // Lunch: 12:30 PM
        scheduleMealReminder(hour: 12, minute: 30, mealType: "lunch", identifier: "meal-lunch")
        
        // Dinner: 7:00 PM
        scheduleMealReminder(hour: 19, minute: 0, mealType: "dinner", identifier: "meal-dinner")
        
        // Snack: 3:00 PM
        scheduleMealReminder(hour: 15, minute: 0, mealType: "snack", identifier: "meal-snack")
    }
    
    private func scheduleMealReminder(hour: Int, minute: Int, mealType: String, identifier: String) {
        // Add random time offset ±12 minutes for natural feel
        let randomOffset = Int.random(in: -12...12)
        let adjustedMinute = max(0, min(59, minute + randomOffset))
        
        // Fetch AI-generated reminder content from backend
        Task {
            do {
                let content = try await fetchAIMealReminder(mealType: mealType)
                createNotification(
                    identifier: identifier,
                    title: content.title,
                    body: content.body,
                    hour: hour,
                    minute: adjustedMinute,
                    repeats: true
                )
            } catch {
                // Use randomized fallback message from pool
                let pool = ViralEngagementManager.mealReminderMessages
                let msg = pool.randomElement() ?? (title: "Time to eat! 🍽️", body: "Don't forget your \(mealType).")
                createNotification(
                    identifier: identifier,
                    title: msg.title,
                    body: msg.body,
                    hour: hour,
                    minute: adjustedMinute,
                    repeats: true
                )
            }
        }
    }
    
    // MARK: - Water Reminders
    
    private func scheduleWaterReminders() {
        // Schedule water reminders every 2 hours from 8 AM to 8 PM
        for hour in stride(from: 8, through: 20, by: 2) {
            scheduleWaterReminder(hour: hour, identifier: "water-\(hour)")
        }
    }
    
    private func scheduleWaterReminder(hour: Int, identifier: String) {
        // Add random time offset ±15 minutes
        let randomMinute = Int.random(in: 0...30)
        
        Task {
            do {
                let content = try await fetchAIWaterReminder()
                createNotification(
                    identifier: identifier,
                    title: content.title,
                    body: content.body,
                    hour: hour,
                    minute: randomMinute,
                    repeats: true
                )
            } catch {
                // Use randomized fallback message
                let pool = ViralEngagementManager.waterReminderMessages
                let msg = pool.randomElement() ?? (title: "Stay Hydrated! 💧", body: "Time to drink water!")
                createNotification(
                    identifier: identifier,
                    title: msg.title,
                    body: msg.body,
                    hour: hour,
                    minute: randomMinute,
                    repeats: true
                )
            }
        }
    }
    
    // MARK: - Workout Reminders
    
    private func scheduleWorkoutReminders() {
        // Morning workout: 7:00 AM (if user prefers morning workouts)
        scheduleWorkoutReminder(hour: 7, minute: 0, identifier: "workout-morning")
        
        // Evening workout: 6:00 PM (if user prefers evening workouts)
        scheduleWorkoutReminder(hour: 18, minute: 0, identifier: "workout-evening")
    }
    
    private func scheduleWorkoutReminder(hour: Int, minute: Int, identifier: String) {
        // Add random time offset ±10 minutes
        let randomOffset = Int.random(in: -10...10)
        let adjustedMinute = max(0, min(59, minute + randomOffset))
        
        Task {
            do {
                let content = try await fetchAIWorkoutReminder()
                createNotification(
                    identifier: identifier,
                    title: content.title,
                    body: content.body,
                    hour: hour,
                    minute: adjustedMinute,
                    repeats: true
                )
            } catch {
                // Use randomized fallback message
                let pool = ViralEngagementManager.workoutReminderMessages
                let msg = pool.randomElement() ?? (title: "Workout Time! 💪", body: "Time for your workout!")
                createNotification(
                    identifier: identifier,
                    title: msg.title,
                    body: msg.body,
                    hour: hour,
                    minute: adjustedMinute,
                    repeats: true
                )
            }
        }
    }
    
    // MARK: - Create Notification
    
    private func createNotification(identifier: String, title: String, body: String, hour: Int, minute: Int, repeats: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule notification \(identifier): \(error.localizedDescription)")
            } else {
                print("✅ Scheduled notification: \(identifier) at \(hour):\(minute)")
            }
        }
    }
    
    // MARK: - AI-Generated Content
    
    private func fetchAIMealReminder(mealType: String) async throws -> (title: String, body: String) {
        guard let token = AuthService.shared.readToken()?.accessToken else {
            throw NSError(domain: "NotificationError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let url = URL(string: "\(NetworkManager.shared.baseURL.absoluteString)/notifications/meal-reminder")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["mealType": mealType]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NSError(domain: "NotificationError", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch AI reminder"])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let title = json["title"] as? String,
           let body = json["body"] as? String {
            return (title, body)
        }
        
        throw NSError(domain: "NotificationError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
    }
    
    private func fetchAIWaterReminder() async throws -> (title: String, body: String) {
        guard let token = AuthService.shared.readToken()?.accessToken else {
            throw NSError(domain: "NotificationError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let url = URL(string: "\(NetworkManager.shared.baseURL.absoluteString)/notifications/water-reminder")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NSError(domain: "NotificationError", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch AI reminder"])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let title = json["title"] as? String,
           let body = json["body"] as? String {
            return (title, body)
        }
        
        throw NSError(domain: "NotificationError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
    }
    
    private func fetchAIWorkoutReminder() async throws -> (title: String, body: String) {
        guard let token = AuthService.shared.readToken()?.accessToken else {
            throw NSError(domain: "NotificationError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let url = URL(string: "\(NetworkManager.shared.baseURL.absoluteString)/notifications/workout-reminder")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NSError(domain: "NotificationError", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch AI reminder"])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let title = json["title"] as? String,
           let body = json["body"] as? String {
            return (title, body)
        }
        
        throw NSError(domain: "NotificationError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
    }
    
    // MARK: - Update Settings
    
    func updateMealReminders(_ enabled: Bool) {
        mealRemindersEnabled = enabled
        saveSettings()
        if enabled {
            scheduleMealReminders()
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["meal-breakfast", "meal-lunch", "meal-dinner", "meal-snack"])
        }
    }
    
    func updateWaterReminders(_ enabled: Bool) {
        waterRemindersEnabled = enabled
        saveSettings()
        if enabled {
            scheduleWaterReminders()
        } else {
            // Only remove the even-hour identifiers that were actually scheduled
            let identifiers = stride(from: 8, through: 20, by: 2).map { "water-\($0)" }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    func updateWorkoutReminders(_ enabled: Bool) {
        workoutRemindersEnabled = enabled
        saveSettings()
        if enabled {
            scheduleWorkoutReminders()
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["workout-morning", "workout-evening"])
        }
    }
    
    // MARK: - Instant Notifications (for WebSocket events)
    
    /// Show instant local notification (for real-time events like friend requests)
    func showLocalNotification(title: String, body: String, sound: UNNotificationSound = .default) {
        guard notificationsEnabled else {
            print("⚠️ Notifications disabled, skipping local notification")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.badge = 1
        
        // Trigger immediately
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // nil trigger = immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to show local notification: \(error.localizedDescription)")
            } else {
                print("✅ Local notification shown: \(title)")
            }
        }
    }
    
    // MARK: - Social Engagement Notifications (Retention & Virality)
    
    /// Schedule social engagement notifications to boost retention
    private func scheduleSocialEngagementNotifications() {
        // Mid-morning social check-in (10:30 AM ± random)
        let socialPool = ViralEngagementManager.socialEngagementMessages
        let morningMsg = socialPool.randomElement() ?? (title: "Check in! 👋", body: "See what your friends are up to!")
        let morningMinute = Int.random(in: 15...45)
        createNotification(
            identifier: "social-morning",
            title: morningMsg.title,
            body: morningMsg.body,
            hour: 10,
            minute: morningMinute,
            repeats: true
        )
        
        // Evening social reminder (8:30 PM ± random)
        let eveningMsg = socialPool.randomElement() ?? (title: "Share your day! 📊", body: "Share your progress with friends!")
        let eveningMinute = Int.random(in: 15...45)
        createNotification(
            identifier: "social-evening",
            title: eveningMsg.title,
            body: eveningMsg.body,
            hour: 20,
            minute: eveningMinute,
            repeats: true
        )
        
        // Weekend challenge reminder (Saturday 9 AM)
        createNotification(
            identifier: "social-weekend",
            title: "Weekend Challenge! 🏆",
            body: "Challenge a friend this weekend! Fitness is better together.",
            hour: 9,
            minute: Int.random(in: 0...30),
            repeats: true
        )
    }
    
    /// Schedule daily motivational notification
    private func scheduleDailyMotivation() {
        let quote = MotivationalQuote.random()
        createNotification(
            identifier: "daily-motivation",
            title: "💡 Daily Motivation",
            body: "\"\(quote.text)\" — \(quote.author)",
            hour: 9,
            minute: Int.random(in: 0...30),
            repeats: true
        )
    }
    
    // MARK: - Chat Notification
    
    /// Schedule a chat reminder if user has unread messages
    func scheduleChatReminder(friendName: String) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "💬 Unread message from \(friendName)"
        content.body = "Don't leave \(friendName) hanging! Reply to keep the conversation going."
        content.sound = .default
        content.badge = 1
        
        // Trigger after 30 minutes
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1800, repeats: false)
        let request = UNNotificationRequest(
            identifier: "chat-reminder-\(friendName)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule chat reminder: \(error.localizedDescription)")
            }
        }
    }
}

