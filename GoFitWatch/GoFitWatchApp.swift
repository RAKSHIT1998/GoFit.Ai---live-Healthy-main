import SwiftUI
import WatchConnectivity

@main
struct GoFitWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityManager()
    
    var body: some Scene {
        WindowGroup {
            WatchTabView()
                .environmentObject(connectivity)
                .onAppear {
                    connectivity.activate()
                }
        }
    }
}

// MARK: - Watch Connectivity Manager
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var waterLiters: Double = 0
    @Published var waterGoal: Double = 2.0
    @Published var calories: Double = 0
    @Published var protein: Double = 0
    @Published var steps: Int = 0
    @Published var mealCount: Int = 0
    @Published var isConnected = false
    
    private var session: WCSession?
    
    override init() {
        super.init()
    }
    
    func activate() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // MARK: - Send Messages to iPhone
    
    func logWater(_ ml: Int) {
        let liters = Double(ml) / 1000.0
        waterLiters += liters
        sendMessage(["action": "logWater", "liters": liters])
    }
    
    func logQuickMeal(name: String, calories: Double) {
        self.calories += calories
        mealCount += 1
        sendMessage(["action": "logQuickMeal", "name": name, "calories": calories])
    }
    
    private func sendMessage(_ message: [String: Any]) {
        guard let session = session, session.isReachable else { return }
        session.sendMessage(message, replyHandler: nil)
    }
    
    // MARK: - WCSession Delegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
        }
        // Request latest data from iPhone
        if activationState == .activated {
            sendMessage(["action": "requestSync"])
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if let water = message["waterLiters"] as? Double { self.waterLiters = water }
            if let goal = message["waterGoal"] as? Double { self.waterGoal = goal }
            if let cal = message["calories"] as? Double { self.calories = cal }
            if let prot = message["protein"] as? Double { self.protein = prot }
            if let st = message["steps"] as? Int { self.steps = st }
            if let mc = message["mealCount"] as? Int { self.mealCount = mc }
        }
    }
    
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            if let water = applicationContext["waterLiters"] as? Double { self.waterLiters = water }
            if let goal = applicationContext["waterGoal"] as? Double { self.waterGoal = goal }
            if let cal = applicationContext["calories"] as? Double { self.calories = cal }
            if let prot = applicationContext["protein"] as? Double { self.protein = prot }
            if let st = applicationContext["steps"] as? Int { self.steps = st }
            if let mc = applicationContext["mealCount"] as? Int { self.mealCount = mc }
        }
    }
}
