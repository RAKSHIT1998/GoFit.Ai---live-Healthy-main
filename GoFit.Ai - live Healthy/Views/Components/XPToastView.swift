import SwiftUI

// MARK: - XP Toast Overlay
/// Animated "+XP" popup that slides in from top when points are earned
struct XPToastView: View {
    let xp: Int
    let reason: String
    @Binding var isShowing: Bool
    
    @State private var offset: CGFloat = -120
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.5
    
    var body: some View {
        if isShowing {
            HStack(spacing: 12) {
                // Animated coin/star
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: .orange.opacity(0.5), radius: 6, x: 0, y: 2)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(scale)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("+\(xp) XP")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(reason)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                // Sparkle icon
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundColor(.yellow)
                    .symbolEffect(.bounce, value: isShowing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.75, blue: 0.3),
                                Color(red: 0.2, green: 0.85, blue: 0.4)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
            )
            .padding(.horizontal, 24)
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    offset = 0
                    opacity = 1
                    scale = 1.0
                }
                // Bounce the star
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.3)) {
                        scale = 1.2
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                            scale = 1.0
                        }
                    }
                }
                // Auto-dismiss after 2.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        offset = -120
                        opacity = 0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        isShowing = false
                    }
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

// MARK: - Reward Toast Modifier
struct RewardToastModifier: ViewModifier {
    @ObservedObject var rewardEngine = RewardEngine.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                XPToastView(
                    xp: rewardEngine.lastXP,
                    reason: rewardEngine.lastReason,
                    isShowing: $rewardEngine.showXPToast
                )
                .padding(.top, 50)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: rewardEngine.showXPToast)
            }
    }
}

extension View {
    func withRewardToasts() -> some View {
        modifier(RewardToastModifier())
    }
}

// MARK: - Reward Engine (Global XP Manager)
@MainActor
class RewardEngine: ObservableObject {
    static let shared = RewardEngine()
    
    @Published var showXPToast = false
    @Published var lastXP: Int = 0
    @Published var lastReason: String = ""
    
    private var toastQueue: [(xp: Int, reason: String)] = []
    private var isProcessing = false
    
    struct XPValues {
        static let mealScanned = 15
        static let mealLogged = 10
        static let liquidLogged = 8
        static let workoutDone = 25
        static let waterGoalMet = 20
        static let streakDay = 12
        static let firstScanOfDay = 20
        static let perfectDay = 50
    }
    
    func awardXP(_ xp: Int, reason: String, actionType: String = "bonus_reward") {
        toastQueue.append((xp: xp, reason: reason))
        StreakManager.shared.awardPoints(xp)
        HapticManager.shared.success()
        Task {
            await syncXPEvent(points: xp, actionType: actionType)
        }
        processQueue()
    }
    
    private func processQueue() {
        guard !isProcessing, let next = toastQueue.first else { return }
        isProcessing = true
        toastQueue.removeFirst()
        
        lastXP = next.xp
        lastReason = next.reason
        showXPToast = true
        
        // Allow next toast after current one finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { [weak self] in
            self?.isProcessing = false
            self?.processQueue()
        }
    }
    
    // MARK: - Convenience Methods
    func rewardMealScan() {
        let isFirst = !UserDefaults.standard.bool(forKey: "scanned_today_\(todayKey)")
        UserDefaults.standard.set(true, forKey: "scanned_today_\(todayKey)")
        
        if isFirst {
            awardXP(XPValues.firstScanOfDay, reason: "First scan of the day! 📸", actionType: "first_meal")
        } else {
            awardXP(XPValues.mealScanned, reason: "Meal scanned! 🍽️", actionType: "log_meal")
        }
    }
    
    func rewardMealLog() {
        awardXP(XPValues.mealLogged, reason: "Meal logged! ✅", actionType: "log_meal")
    }
    
    func rewardLiquidLog(beverageType: String) {
        let emoji: String
        switch beverageType {
        case "water": emoji = "💧"
        case "coffee": emoji = "☕"
        case "tea": emoji = "🍵"
        case "juice": emoji = "🧃"
        default: emoji = "🥤"
        }
        awardXP(XPValues.liquidLogged, reason: "\(beverageType.capitalized) logged! \(emoji)", actionType: "log_water")
    }
    
    func rewardWaterGoal() {
        awardXP(XPValues.waterGoalMet, reason: "Water goal reached! 🎯💧", actionType: "water_goal_met")
    }
    
    private var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func syncXPEvent(points: Int, actionType: String) async {
        do {
            let payload: [String: Any] = [
                "actionType": actionType,
                "points": points
            ]
            let body = try JSONSerialization.data(withJSONObject: payload, options: [])
            _ = try await NetworkManager.shared.requestDictionary("gamification/events", method: "POST", body: body)
        } catch {
            print("⚠️ Failed to sync XP event: \(error.localizedDescription)")
        }
    }
}
