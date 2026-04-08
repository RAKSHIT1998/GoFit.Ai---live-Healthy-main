import Foundation
import UserNotifications

@MainActor
final class RetentionManager: ObservableObject {
    static let shared = RetentionManager()

    enum NextAction: String {
        case workout
        case meal
        case water
        case social

        var title: String {
            switch self {
            case .workout: return "Complete a 5-minute workout"
            case .meal: return "Log your next meal"
            case .water: return "Drink and log 250ml water"
            case .social: return "Send motivation to a friend"
            }
        }

        var subtitle: String {
            switch self {
            case .workout: return "Quick wins build long streaks."
            case .meal: return "A simple log keeps your streak alive."
            case .water: return "Hydration boosts energy and consistency."
            case .social: return "Accountability improves retention."
            }
        }
    }

    enum MeaningfulAction {
        case workoutCompleted
        case mealLogged
        case waterGoalMet
        case socialInteraction
    }

    struct ComebackPlan {
        let title: String
        let message: String
        let ctaTitle: String
        let recommendedAction: NextAction
    }

    @Published var isActivated: Bool = false
    @Published var journeyDay: Int = 1
    @Published var daysSinceLastOpen: Int = 0
    @Published var completionScore: Double = 0
    @Published var nextAction: NextAction = .workout
    @Published var isComebackMode: Bool = false
    @Published var comebackPlan: ComebackPlan?

    private let defaults = UserDefaults.standard

    private let installDateKey = "retention_install_date"
    private let lastOpenDateKey = "retention_last_open_date"
    private let firstMeaningfulActionDateKey = "retention_first_meaningful_action_date"
    private let openHourHistogramKey = "retention_open_hour_histogram"
    private let doneWorkoutDayKey = "retention_done_workout_day"
    private let doneMealDayKey = "retention_done_meal_day"
    private let doneWaterDayKey = "retention_done_water_day"

    private init() {
        ensureInstallDate()
        refreshState()
    }

    func recordAppOpen() {
        let now = Date()
        if let lastOpen = defaults.object(forKey: lastOpenDateKey) as? Date {
            let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: lastOpen), to: Calendar.current.startOfDay(for: now)).day ?? 0
            daysSinceLastOpen = max(0, diff)
        } else {
            daysSinceLastOpen = 0
        }

        defaults.set(now, forKey: lastOpenDateKey)
        updateOpenHourHistogram(for: now)
        refreshState()
        rescheduleWinBackNotification()
    }

    func recordMeaningfulAction(_ action: MeaningfulAction) {
        let todayString = Self.dayString(for: Date())

        if defaults.object(forKey: firstMeaningfulActionDateKey) == nil {
            defaults.set(Date(), forKey: firstMeaningfulActionDateKey)
            isActivated = true
        }

        switch action {
        case .workoutCompleted:
            defaults.set(todayString, forKey: doneWorkoutDayKey)
        case .mealLogged:
            defaults.set(todayString, forKey: doneMealDayKey)
        case .waterGoalMet:
            defaults.set(todayString, forKey: doneWaterDayKey)
        case .socialInteraction:
            break
        }

        refreshState()
        rescheduleWinBackNotification()
    }

    private func refreshState() {
        ensureInstallDate()

        let now = Date()
        let installDate = (defaults.object(forKey: installDateKey) as? Date) ?? now
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: installDate), to: Calendar.current.startOfDay(for: now)).day ?? 0
        journeyDay = max(1, min(7, days + 1))

        isActivated = defaults.object(forKey: firstMeaningfulActionDateKey) as? Date != nil

        let today = Self.dayString(for: now)
        let workoutDone = defaults.string(forKey: doneWorkoutDayKey) == today
        let mealDone = defaults.string(forKey: doneMealDayKey) == today
        let waterDone = defaults.string(forKey: doneWaterDayKey) == today

        let completedCount = [workoutDone, mealDone, waterDone].filter { $0 }.count
        completionScore = Double(completedCount) / 3.0

        if let lastOpen = defaults.object(forKey: lastOpenDateKey) as? Date {
            let diff = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: lastOpen), to: Calendar.current.startOfDay(for: now)).day ?? 0
            daysSinceLastOpen = max(0, diff)
        }

        if !workoutDone {
            nextAction = .workout
        } else if !mealDone {
            nextAction = .meal
        } else if !waterDone {
            nextAction = .water
        } else {
            nextAction = .social
        }

        isComebackMode = daysSinceLastOpen >= 3
        comebackPlan = buildComebackPlan()
    }

    func dismissComebackMode() {
        isComebackMode = false
        comebackPlan = nil
    }

    func completeComebackSession() {
        dismissComebackMode()
        rescheduleWinBackNotification()
    }

    private func ensureInstallDate() {
        if defaults.object(forKey: installDateKey) == nil {
            defaults.set(Date(), forKey: installDateKey)
        }
    }

    private func updateOpenHourHistogram(for date: Date) {
        let hour = Calendar.current.component(.hour, from: date)
        var histogram = (defaults.dictionary(forKey: openHourHistogramKey) as? [String: Int]) ?? [:]
        histogram["\(hour)", default: 0] += 1
        defaults.set(histogram, forKey: openHourHistogramKey)
    }

    private func preferredOpenHour() -> Int {
        let histogram = (defaults.dictionary(forKey: openHourHistogramKey) as? [String: Int]) ?? [:]
        if let best = histogram.max(by: { $0.value < $1.value }), let hour = Int(best.key) {
            return hour
        }
        return 19
    }

    private func rescheduleWinBackNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["retention_winback_24h", "retention_habit_hour"])

        let winbackContent = UNMutableNotificationContent()
        if let comebackPlan {
            winbackContent.title = comebackPlan.title
            winbackContent.body = comebackPlan.message
        } else {
            winbackContent.title = isActivated ? "We saved your progress 💪" : "Start your first win today 🌟"
            winbackContent.body = nextAction.title
        }
        winbackContent.sound = .default

        let winbackTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
        let winbackRequest = UNNotificationRequest(identifier: "retention_winback_24h", content: winbackContent, trigger: winbackTrigger)
        center.add(winbackRequest)

        var dateComponents = DateComponents()
        dateComponents.hour = preferredOpenHour()
        dateComponents.minute = 0

        let habitContent = UNMutableNotificationContent()
        habitContent.title = "Your consistency slot is open ⏰"
        habitContent.body = nextAction.subtitle
        habitContent.sound = .default

        let habitTrigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let habitRequest = UNNotificationRequest(identifier: "retention_habit_hour", content: habitContent, trigger: habitTrigger)
        center.add(habitRequest)
    }

    private static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func buildComebackPlan() -> ComebackPlan? {
        guard daysSinceLastOpen >= 3 else { return nil }

        switch nextAction {
        case .workout:
            return ComebackPlan(
                title: "Welcome back — restart with 5 minutes 💪",
                message: "You were away for \(daysSinceLastOpen) days. We trimmed today down to one short workout.",
                ctaTitle: "Start quick workout",
                recommendedAction: .workout
            )
        case .meal:
            return ComebackPlan(
                title: "Welcome back — log one meal 🍽️",
                message: "No pressure. One simple meal log gets your momentum back after \(daysSinceLastOpen) days away.",
                ctaTitle: "Log first meal",
                recommendedAction: .meal
            )
        case .water:
            return ComebackPlan(
                title: "Welcome back — easy hydration win 💧",
                message: "Start small after \(daysSinceLastOpen) inactive days. Log one glass of water and rebuild consistency.",
                ctaTitle: "Log water",
                recommendedAction: .water
            )
        case .social:
            return ComebackPlan(
                title: "Welcome back — reconnect with friends 👋",
                message: "Social accountability helps people stick. Share progress and get back into your routine.",
                ctaTitle: "Share progress",
                recommendedAction: .social
            )
        }
    }
}
