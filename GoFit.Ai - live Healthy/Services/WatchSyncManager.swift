import Foundation
import WatchConnectivity

final class WatchSyncManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSyncManager()

    @Published var isPaired = false
    @Published var isWatchAppInstalled = false
    @Published var activationState: WCSessionActivationState = .notActivated

    private override init() {
        super.init()
    }

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        Task { @MainActor in
            self.updateStatus(session)
        }
    }

    func sendNutritionUpdate(_ payload: WatchNutritionPayload) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        do {
            let data = try JSONEncoder().encode(payload)
            try session.updateApplicationContext(["nutrition": data])
        } catch {
            print("❌ Failed to send nutrition to watch: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.updateStatus(session)
        }
        if let error = error {
            print("❌ Watch session activation failed: \(error.localizedDescription)")
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.updateStatus(session)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let action = message["action"] as? String else { return }
        Task { @MainActor in
            switch action {
            case "openScanner":
                NotificationCenter.default.post(name: .openMealScannerFromWatch, object: nil)
            case "openWaterLog":
                NotificationCenter.default.post(name: .openWaterLogFromWatch, object: nil)
            case "logWater":
                // Support both "amount" (legacy) and "liters" (new watch app) keys
                let liters: Double
                if let l = message["liters"] as? Double, l > 0 {
                    liters = l
                } else if let a = message["amount"] as? Double, a > 0 {
                    liters = a
                } else {
                    break
                }
                WaterIntakeManager.shared.logWater(liters)
                GoFitWidgetDataStore.shared.refresh()
                // Send updated data back to watch
                self.sendCurrentDataToWatch(session)
            case "logQuickMeal":
                if let name = message["name"] as? String {
                    // Support calories as both Int and Double
                    let cal: Double
                    if let c = message["calories"] as? Double {
                        cal = c
                    } else if let c = message["calories"] as? Int {
                        cal = Double(c)
                    } else {
                        cal = 100
                    }
                    let item = MealItem(name: name, calories: cal, protein: 0, carbs: 0, fat: 0, sugar: 0)
                    let meal = LoggedMeal(timestamp: Date(), mealType: .snack, items: [item], totalCalories: cal, totalProtein: 0, totalCarbs: 0, totalFat: 0, totalSugar: 0)
                    LocalDailyLogStore.shared.addMeal(meal)
                    GoFitWidgetDataStore.shared.refresh()
                    NotificationCenter.default.post(name: NSNotification.Name("MealSaved"), object: nil)
                    // Send updated data back to watch
                    self.sendCurrentDataToWatch(session)
                }
            case "requestSync":
                // Watch app is asking for current data
                self.sendCurrentDataToWatch(session)
            default:
                break
            }
        }
    }
    
    /// Send the current day's data to the watch app
    @MainActor
    private func sendCurrentDataToWatch(_ session: WCSession) {
        guard session.isReachable else { return }
        let water = WaterIntakeManager.shared
        let log = LocalDailyLogStore.shared.getTodayLog()
        let reply: [String: Any] = [
            "waterLiters": water.todayWaterIntake,
            "waterGoal": water.waterGoal,
            "calories": log.totalCalories,
            "protein": log.totalProtein,
            "steps": Int(log.steps ?? 0),
            "mealCount": log.meals.count
        ]
        session.sendMessage(reply, replyHandler: nil)
    }

    @MainActor
    private func updateStatus(_ session: WCSession) {
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        activationState = session.activationState
    }
}

extension Notification.Name {
    static let openMealScannerFromWatch = Notification.Name("openMealScannerFromWatch")
    static let openWaterLogFromWatch = Notification.Name("openWaterLogFromWatch")
}
