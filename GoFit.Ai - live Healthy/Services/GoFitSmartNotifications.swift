import Foundation
import UserNotifications

// MARK: - GoFit Smart Notifications
/// Context-aware notification system that sends cool, motivating notifications:
/// - Smart hydration nudges based on time of day
/// - Meal logging reminders with fun messages
/// - Goal celebration alerts (confetti-style)
/// - Workout motivation
/// - Streak reminders
/// Works on both iPhone and Apple Watch.

@MainActor
final class GoFitSmartNotifications {
    static let shared = GoFitSmartNotifications()
    private init() {}
    
    // MARK: - Schedule All Smart Notifications
    
    func scheduleSmartNotifications() {
        let center = UNUserNotificationCenter.current()
        
        // Remove old smart notifications (keep base ones from NotificationService)
        center.getPendingNotificationRequests { requests in
            let smartIDs = requests
                .filter { $0.identifier.hasPrefix("smart_") }
                .map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: smartIDs)
        }
        
        scheduleHydrationNudges()
        scheduleMealNudges()
        scheduleGoalStatusCheck()
        scheduleWorkoutMotivation()
        scheduleStreakReminder()
        scheduleWeeklySummary()
    }
    
    // MARK: - 💧 Smart Hydration Nudges
    
    private func scheduleHydrationNudges() {
        let nudges: [(hour: Int, minute: Int, messages: [(String, String)])] = [
            (9, 0, [
                ("Good morning! ☀️", "Start your day with a glass of water 💧"),
                ("Rise & Hydrate 🌅", "Your body lost water while sleeping — drink up!"),
                ("Morning Boost 💧", "Water first, coffee second ☕"),
            ]),
            (11, 30, [
                ("Midmorning Check 💧", "Had your water? Your brain needs it to focus 🧠"),
                ("Stay Sharp! 🎯", "Dehydration drops focus by 25%. Quick sip?"),
                ("Water Break ⏰", "Take 30 seconds. Drink 250ml. Feel great."),
            ]),
            (14, 0, [
                ("Afternoon Slump? 😴", "Skip the coffee, grab water instead! 💧"),
                ("Post-Lunch Hydration 🥤", "Your body is digesting — help it out with water!"),
                ("2PM Power-Up ⚡", "A glass of water beats a nap. Try it!"),
            ]),
            (16, 30, [
                ("Pre-Workout Fuel 💪", "Hydrate now for a better evening workout!"),
                ("Tea Time? 🍵", "Green tea counts towards your water goal!"),
                ("Almost There! 🏁", "Check your water progress — you might be close to your goal!"),
            ]),
            (19, 0, [
                ("Evening Reminder 🌙", "Don't forget to log your drinks today!"),
                ("Wind Down 🫖", "Herbal tea is a great way to hit your water goal"),
                ("Last Call 💧", "One more glass and you're golden for today! ✨"),
            ]),
        ]
        
        for nudge in nudges {
            guard let msg = nudge.messages.randomElement() else { continue }
            scheduleNotification(
                id: "smart_water_\(nudge.hour)",
                title: msg.0,
                body: msg.1,
                hour: nudge.hour,
                minute: nudge.minute + Int.random(in: -5...5),
                repeats: true,
                categoryIdentifier: "WATER_REMINDER",
                sound: .default
            )
        }
    }
    
    // MARK: - 🍽️ Meal Nudges
    
    private func scheduleMealNudges() {
        let meals: [(hour: Int, minute: Int, meal: String, messages: [(String, String)])] = [
            (8, 15, "breakfast", [
                ("🍳 Breakfast Time!", "Fuel your morning! Scan your breakfast to track it."),
                ("Good Morning Chef! 👨‍🍳", "What's for breakfast? Let's log it!"),
                ("Don't Skip! 🥣", "Breakfast eaters burn 5-20% more calories. Let's go!"),
            ]),
            (12, 45, "lunch", [
                ("🥗 Lunch Break!", "Take a photo of your lunch — we'll handle the rest!"),
                ("Halfway There! 🌞", "Log your lunch to stay on track today."),
                ("Lunch O'Clock 🕐", "Quick scan = instant nutrition tracking. Easy!"),
            ]),
            (19, 15, "dinner", [
                ("🍽️ Dinner Time!", "End the day strong — scan your dinner!"),
                ("Last Meal of the Day 🌙", "Let's make it count! Log your dinner."),
                ("Chef's Kiss! 👨‍🍳", "Whatever you're having, scan it!"),
            ]),
        ]
        
        for meal in meals {
            guard let msg = meal.messages.randomElement() else { continue }
            scheduleNotification(
                id: "smart_meal_\(meal.meal)",
                title: msg.0,
                body: msg.1,
                hour: meal.hour,
                minute: meal.minute + Int.random(in: -8...8),
                repeats: true,
                categoryIdentifier: "MEAL_REMINDER",
                sound: .default
            )
        }
    }
    
    // MARK: - 🏆 Goal Status

    private func scheduleGoalStatusCheck() {
        let todayLog = LocalDailyLogStore.shared.getTodayLog()
        let waterGoal = LocalUserStore.shared.getProfile()?.liquidIntakeGoal
            ?? WaterIntakeManager.shared.waterGoal
        let currentWater = todayLog.totalLiquid

        // Do not pre-schedule celebratory notifications. Real celebrations are sent
        // at the moment the user actually hits the goal via sendGoalHitNotification.
        guard waterGoal > 0, currentWater < waterGoal else { return }

        let remaining = max(0, waterGoal - currentWater)
        let currentWaterText = String(format: "%.1f", currentWater)
        let waterGoalText = String(format: "%.1f", waterGoal)
        let remainingText = String(format: "%.1f", remaining)

        let reminderOptions: [(String, String)] = [
            ("💧 Water Check-In", "You're at \(currentWaterText)L of \(waterGoalText)L today. \(remainingText)L to go."),
            ("🌙 Finish Strong", "You still need \(remainingText)L to hit today's hydration goal."),
            ("⏰ Hydration Reminder", "Logged \(currentWaterText)L so far. One more push toward \(waterGoalText)L.")
        ]

        guard let reminder = reminderOptions.randomElement() else { return }
        scheduleNotification(
            id: "smart_goal_status",
            title: reminder.0,
            body: reminder.1,
            hour: 21,
            minute: 0,
            repeats: false,
            categoryIdentifier: "GOAL_CELEBRATION",
            sound: .default
        )
    }
    
    // MARK: - 🏋️ Workout Motivation
    
    private func scheduleWorkoutMotivation() {
        let messages: [(String, String)] = [
            ("💪 Time to Move!", "Even 15 minutes counts. Your future self will thank you."),
            ("🔥 Burn Mode", "Ready to crush a workout? Let's go!"),
            ("🏃 No Excuses!", "The hardest part is starting. You got this!"),
            ("⚡ Energy Boost", "A quick workout = hours of extra energy. Worth it!"),
        ]
        
        guard let msg = messages.randomElement() else { return }
        scheduleNotification(
            id: "smart_workout",
            title: msg.0,
            body: msg.1,
            hour: 17,
            minute: 30 + Int.random(in: -15...15),
            repeats: true,
            categoryIdentifier: "WORKOUT_REMINDER",
            sound: .default
        )
    }
    
    // MARK: - 🔥 Streak Reminder
    
    private func scheduleStreakReminder() {
        // Remind at 8 PM to not break streak
        let messages: [(String, String)] = [
            ("🔥 Don't Break Your Streak!", "Log at least one meal today to keep it alive!"),
            ("⏰ Almost Midnight!", "Quick — scan something to keep your tracking streak!"),
            ("📊 Streak Alert", "You've been crushing it! Don't stop now."),
        ]
        
        guard let msg = messages.randomElement() else { return }
        scheduleNotification(
            id: "smart_streak",
            title: msg.0,
            body: msg.1,
            hour: 20,
            minute: 30,
            repeats: true,
            categoryIdentifier: "STREAK_REMINDER",
            sound: .default
        )
    }
    
    // MARK: - 📊 Weekly Summary
    
    private func scheduleWeeklySummary() {
        // Sunday at 10 AM
        let content = UNMutableNotificationContent()
        content.title = "📊 Your Weekly GoFit Summary"
        content.body = "Tap to see how you did this week — calories, water, workouts & more!"
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_SUMMARY"
        
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 10
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "smart_weekly_summary", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule weekly summary: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Instant Celebration (call when goal is hit)
    
    /// Immediately send a celebration notification — call when water goal is reached
    func sendGoalHitNotification(type: String) {
        let content = UNMutableNotificationContent()
        
        switch type {
        case "water":
            content.title = "🎊 Water Goal Complete!"
            content.body = "You've hit your daily water target! Your body thanks you 💧"
        case "calories":
            content.title = "🎯 Calorie Goal Met!"
            content.body = "Perfect nutrition today! Keep up the amazing work 🌟"
        case "steps":
            content.title = "👟 Step Goal Crushed!"
            content.body = "You've been walking like a champion today! 🏆"
        default:
            content.title = "🎉 Goal Achieved!"
            content.body = "Another goal down! You're on a roll!"
        }
        
        content.sound = .default
        content.categoryIdentifier = "GOAL_HIT"
        
        // Fire in 1 second
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "instant_\(type)_\(UUID().uuidString.prefix(6))", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Register Notification Categories (for actions)
    
    func registerCategories() {
        let waterAction = UNNotificationAction(
            identifier: "LOG_WATER_250",
            title: "💧 Log 250ml",
            options: .foreground
        )
        let waterAction500 = UNNotificationAction(
            identifier: "LOG_WATER_500",
            title: "💧 Log 500ml",
            options: .foreground
        )
        let scanAction = UNNotificationAction(
            identifier: "SCAN_MEAL",
            title: "📸 Scan Food",
            options: .foreground
        )
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Later",
            options: .destructive
        )
        
        let waterCategory = UNNotificationCategory(
            identifier: "WATER_REMINDER",
            actions: [waterAction, waterAction500, dismissAction],
            intentIdentifiers: []
        )
        let mealCategory = UNNotificationCategory(
            identifier: "MEAL_REMINDER",
            actions: [scanAction, dismissAction],
            intentIdentifiers: []
        )
        let goalCategory = UNNotificationCategory(
            identifier: "GOAL_CELEBRATION",
            actions: [],
            intentIdentifiers: []
        )
        let workoutCategory = UNNotificationCategory(
            identifier: "WORKOUT_REMINDER",
            actions: [dismissAction],
            intentIdentifiers: []
        )
        let streakCategory = UNNotificationCategory(
            identifier: "STREAK_REMINDER",
            actions: [scanAction, waterAction, dismissAction],
            intentIdentifiers: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            waterCategory, mealCategory, goalCategory, workoutCategory, streakCategory
        ])
    }
    
    // MARK: - Helpers
    
    private func scheduleNotification(
        id: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int,
        repeats: Bool,
        categoryIdentifier: String,
        sound: UNNotificationSound
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound
        content.categoryIdentifier = categoryIdentifier
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = max(0, min(59, minute))
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule \(id): \(error.localizedDescription)")
            } else {
                print("✅ Scheduled: \(id) at \(hour):\(max(0, min(59, minute)))")
            }
        }
    }
}
