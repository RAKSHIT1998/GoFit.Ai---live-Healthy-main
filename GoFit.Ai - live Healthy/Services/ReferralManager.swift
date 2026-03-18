import Foundation
import SwiftUI

// MARK: - Referral Tier System
enum ReferralTier: Int, CaseIterable, Codable {
    case starter = 0
    case bronze = 1
    case silver = 2
    case gold = 3
    case platinum = 4
    case diamond = 5
    
    var name: String {
        switch self {
        case .starter: return "Starter"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        }
    }
    
    var emoji: String {
        switch self {
        case .starter: return "🌱"
        case .bronze: return "🥉"
        case .silver: return "🥈"
        case .gold: return "🥇"
        case .platinum: return "💎"
        case .diamond: return "👑"
        }
    }
    
    var requiredReferrals: Int {
        switch self {
        case .starter: return 0
        case .bronze: return 3
        case .silver: return 7
        case .gold: return 15
        case .platinum: return 30
        case .diamond: return 50
        }
    }
    
    var xpReward: Int {
        switch self {
        case .starter: return 0
        case .bronze: return 500
        case .silver: return 1500
        case .gold: return 3000
        case .platinum: return 7500
        case .diamond: return 15000
        }
    }
    
    var perReferralXP: Int {
        switch self {
        case .starter: return 50
        case .bronze: return 75
        case .silver: return 100
        case .gold: return 150
        case .platinum: return 200
        case .diamond: return 300
        }
    }
    
    var color: Color {
        switch self {
        case .starter: return Color.green
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.8)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .platinum: return Color(red: 0.4, green: 0.6, blue: 1.0)
        case .diamond: return Color(red: 0.7, green: 0.3, blue: 1.0)
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .starter: return [.green.opacity(0.6), .green]
        case .bronze: return [Color(red: 0.8, green: 0.5, blue: 0.2), Color(red: 0.9, green: 0.65, blue: 0.3)]
        case .silver: return [Color(red: 0.6, green: 0.6, blue: 0.7), Color(red: 0.85, green: 0.85, blue: 0.9)]
        case .gold: return [Color(red: 1.0, green: 0.7, blue: 0.0), Color(red: 1.0, green: 0.9, blue: 0.3)]
        case .platinum: return [Color(red: 0.3, green: 0.5, blue: 1.0), Color(red: 0.6, green: 0.8, blue: 1.0)]
        case .diamond: return [Color(red: 0.5, green: 0.2, blue: 1.0), Color(red: 0.9, green: 0.4, blue: 1.0)]
        }
    }
    
    var perkDescription: String {
        switch self {
        case .starter: return "Start referring friends to earn rewards!"
        case .bronze: return "Unlock 2x Daily Spin rewards"
        case .silver: return "Exclusive Silver badge + Priority support"
        case .gold: return "1 month Premium free + Gold profile frame"
        case .platinum: return "3 months Premium + Custom themes"
        case .diamond: return "Lifetime Premium + Diamond Crown badge"
        }
    }
    
    var nextTier: ReferralTier? {
        ReferralTier(rawValue: rawValue + 1)
    }
}

// MARK: - Referral Record
struct ReferralRecord: Codable, Identifiable {
    let id: String
    let friendName: String
    let date: Date
    let xpEarned: Int
    let tierAtTime: ReferralTier
    
    init(friendName: String, xpEarned: Int, tierAtTime: ReferralTier) {
        self.id = UUID().uuidString
        self.friendName = friendName
        self.date = Date()
        self.xpEarned = xpEarned
        self.tierAtTime = tierAtTime
    }
}

// MARK: - Referral Manager
@MainActor
class ReferralManager: ObservableObject {
    static let shared = ReferralManager()
    
    @Published var referralCode: String = ""
    @Published var totalReferrals: Int = 0
    @Published var currentTier: ReferralTier = .starter
    @Published var totalXPEarned: Int = 0
    @Published var referralHistory: [ReferralRecord] = []
    @Published var showTierUpCelebration: Bool = false
    @Published var newTierReached: ReferralTier? = nil
    @Published var dailyShareCount: Int = 0
    @Published var weeklyShareCount: Int = 0
    
    // Streak for sharing
    @Published var shareStreak: Int = 0
    
    private let defaults = UserDefaults.standard
    
    private init() {
        loadData()
    }
    
    // MARK: - Referral Code
    
    func generateCode(for userId: String, name: String) -> String {
        if !referralCode.isEmpty { return referralCode }
        
        // Generate a catchy, memorable code
        let cleanName = name.replacingOccurrences(of: " ", with: "")
            .prefix(4).uppercased()
        let shortId = String(userId.prefix(3)).uppercased()
        let code = "GOFIT\(cleanName)\(shortId)"
        
        referralCode = code
        defaults.set(code, forKey: "referral_code_v2")
        return code
    }
    
    // MARK: - Process Referral
    
    func processNewReferral(friendName: String) {
        totalReferrals += 1
        
        let xp = currentTier.perReferralXP
        totalXPEarned += xp
        
        let record = ReferralRecord(
            friendName: friendName,
            xpEarned: xp,
            tierAtTime: currentTier
        )
        referralHistory.insert(record, at: 0)
        
        // Check tier upgrade
        let newTier = calculateTier()
        if newTier.rawValue > currentTier.rawValue {
            // Tier up!
            totalXPEarned += newTier.xpReward
            currentTier = newTier
            newTierReached = newTier
            showTierUpCelebration = true
            HapticManager.notification(type: .success)
        }
        
        // Award XP to StreakManager
        StreakManager.shared.awardPoints(xp)
        
        saveData()
    }
    
    // MARK: - Record Share
    
    func recordShare() {
        dailyShareCount += 1
        weeklyShareCount += 1
        
        // Share streak logic
        let today = Calendar.current.startOfDay(for: Date())
        let lastShare = defaults.object(forKey: "last_share_date_v2") as? Date
        
        if let last = lastShare {
            let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last), to: today).day ?? 0
            if days == 1 {
                shareStreak += 1
            } else if days > 1 {
                shareStreak = 1
            }
        } else {
            shareStreak = 1
        }
        
        defaults.set(today, forKey: "last_share_date_v2")
        defaults.set(shareStreak, forKey: "share_streak_v2")
        
        // Bonus XP for sharing
        let shareXP = min(dailyShareCount, 3) * 10 // Max 30 XP/day from shares
        StreakManager.shared.awardPoints(shareXP)
        
        saveData()
    }
    
    // MARK: - Shareable Content
    
    func getInviteMessage(userName: String) -> String {
        """
        Hey! 💪 \(userName) invited you to GoFit.Ai — the smartest AI fitness app!
        
        🤖 AI-powered meal scanning
        🏆 Compete with friends on leaderboards  
        📊 Smart health insights & workout plans
        🎮 Fun challenges & daily rewards
        🔥 Track streaks & level up!
        
        Use my code: \(referralCode) — we BOTH get bonus XP! 🎁
        
        Download free → https://apps.apple.com/app/gofit-ai
        
        #GoFitAi #FitnessApp
        """
    }
    
    func getShortInvite(userName: String) -> String {
        "💪 \(userName) invited you to GoFit.Ai! Use code \(referralCode) for bonus rewards 🎁 https://apps.apple.com/app/gofit-ai"
    }
    
    func getInstagramCaption(userName: String) -> String {
        """
        Just hit \(totalReferrals) referrals on @GoFitAi! \(currentTier.emoji)
        
        This app literally changed my fitness game — AI meal scanning, smart workouts, daily challenges... it's addicting 🔥
        
        Use my code: \(referralCode) to get started!
        Link in bio 👆
        
        #GoFitAi #FitnessApp #AIFitness #HealthyLifestyle #FitnessMotivation #GymLife #FitFam #WorkoutMotivation
        """
    }
    
    // MARK: - Tier Calculation
    
    private func calculateTier() -> ReferralTier {
        for tier in ReferralTier.allCases.reversed() {
            if totalReferrals >= tier.requiredReferrals {
                return tier
            }
        }
        return .starter
    }
    
    var progressToNextTier: Double {
        guard let next = currentTier.nextTier else { return 1.0 }
        let current = currentTier.requiredReferrals
        let needed = next.requiredReferrals
        let progress = Double(totalReferrals - current) / Double(needed - current)
        return min(max(progress, 0), 1)
    }
    
    var referralsToNextTier: Int {
        guard let next = currentTier.nextTier else { return 0 }
        return max(next.requiredReferrals - totalReferrals, 0)
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        defaults.set(totalReferrals, forKey: "total_referrals_v2")
        defaults.set(currentTier.rawValue, forKey: "referral_tier_v2")
        defaults.set(totalXPEarned, forKey: "referral_xp_v2")
        defaults.set(dailyShareCount, forKey: "daily_share_count_v2")
        defaults.set(weeklyShareCount, forKey: "weekly_share_count_v2")
        
        if let data = try? JSONEncoder().encode(referralHistory) {
            defaults.set(data, forKey: "referral_history_v2")
        }
    }
    
    private func loadData() {
        referralCode = defaults.string(forKey: "referral_code_v2") ?? ""
        totalReferrals = defaults.integer(forKey: "total_referrals_v2")
        currentTier = ReferralTier(rawValue: defaults.integer(forKey: "referral_tier_v2")) ?? .starter
        totalXPEarned = defaults.integer(forKey: "referral_xp_v2")
        shareStreak = defaults.integer(forKey: "share_streak_v2")
        dailyShareCount = defaults.integer(forKey: "daily_share_count_v2")
        weeklyShareCount = defaults.integer(forKey: "weekly_share_count_v2")
        
        if let data = defaults.data(forKey: "referral_history_v2"),
           let history = try? JSONDecoder().decode([ReferralRecord].self, from: data) {
            referralHistory = history
        }
        
        // Reset daily count if new day
        let lastDate = defaults.object(forKey: "last_share_date_v2") as? Date
        if let last = lastDate, !Calendar.current.isDateInToday(last) {
            dailyShareCount = 0
        }
    }
}
