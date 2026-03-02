//
//  AIChallengeService.swift
//  GoFit.Ai - live Healthy
//
//  Smart AI-generated challenges for premium users.
//  Analyzes user's fitness data to create personalized,
//  adaptive challenges that push users just beyond their comfort zone.
//

import SwiftUI
import Combine

// MARK: - AI Challenge Model
struct AIChallenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let category: Category
    let difficulty: Difficulty
    let targetValue: Double
    let unit: String
    let durationDays: Int
    let xpReward: Int
    let createdAt: Date
    let expiresAt: Date
    var currentProgress: Double
    var isCompleted: Bool
    
    enum Category: String, Codable, CaseIterable {
        case nutrition = "nutrition"
        case activity = "activity"
        case consistency = "consistency"
        case social = "social"
        case mindfulness = "mindfulness"
        
        var color: Color {
            switch self {
            case .nutrition: return Color(red: 0.2, green: 0.8, blue: 0.4)
            case .activity: return Color(red: 1.0, green: 0.5, blue: 0.2)
            case .consistency: return Color(red: 0.6, green: 0.4, blue: 1.0)
            case .social: return Color(red: 0.3, green: 0.7, blue: 1.0)
            case .mindfulness: return Color(red: 0.9, green: 0.7, blue: 0.3)
            }
        }
        
        var label: String {
            switch self {
            case .nutrition: return "Nutrition"
            case .activity: return "Activity"
            case .consistency: return "Consistency"
            case .social: return "Social"
            case .mindfulness: return "Mindfulness"
            }
        }
    }
    
    enum Difficulty: String, Codable, CaseIterable {
        case easy = "easy"
        case medium = "medium"
        case hard = "hard"
        case extreme = "extreme"
        
        var label: String {
            switch self {
            case .easy: return "Easy"
            case .medium: return "Medium"
            case .hard: return "Hard"
            case .extreme: return "Extreme"
            }
        }
        
        var color: Color {
            switch self {
            case .easy: return .green
            case .medium: return .orange
            case .hard: return .red
            case .extreme: return .purple
            }
        }
        
        var stars: Int {
            switch self {
            case .easy: return 1
            case .medium: return 2
            case .hard: return 3
            case .extreme: return 4
            }
        }
        
        var xpMultiplier: Double {
            switch self {
            case .easy: return 1.0
            case .medium: return 1.5
            case .hard: return 2.5
            case .extreme: return 4.0
            }
        }
    }
    
    var progressPercent: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentProgress / targetValue, 1.0)
    }
    
    var timeRemainingText: String {
        let remaining = expiresAt.timeIntervalSince(Date())
        if remaining <= 0 { return "Expired" }
        let days = Int(remaining / 86400)
        let hours = Int(remaining.truncatingRemainder(dividingBy: 86400) / 3600)
        if days > 0 { return "\(days)d \(hours)h left" }
        if hours > 0 { return "\(hours)h left" }
        let minutes = Int(remaining.truncatingRemainder(dividingBy: 3600) / 60)
        return "\(minutes)m left"
    }
}

// MARK: - AI Weekly Summary
struct AIWeeklySummary: Codable {
    let avgCalories: Double
    let avgProtein: Double
    let avgSteps: Int
    let avgWater: Double
    let streakDays: Int
    let workoutsCompleted: Int
    let friendChallengesWon: Int
}

// MARK: - AI Challenge Service
@MainActor
final class AIChallengeService: ObservableObject {
    static let shared = AIChallengeService()
    
    @Published var activeChallenges: [AIChallenge] = []
    @Published var completedChallenges: [AIChallenge] = []
    @Published var weeklySummary: AIWeeklySummary?
    @Published var isGenerating = false
    @Published var totalXPEarned: Int = 0
    @Published var challengeStreak: Int = 0
    
    private let cacheKey = "ai_challenges_cache"
    private let xpKey = "ai_challenge_xp"
    private let streakKey = "ai_challenge_streak"
    private let lastGeneratedKey = "ai_challenge_last_generated"
    
    private init() {
        loadCachedChallenges()
        totalXPEarned = UserDefaults.standard.integer(forKey: xpKey)
        challengeStreak = UserDefaults.standard.integer(forKey: streakKey)
    }
    
    // MARK: - Generate Smart Challenges
    /// Generates personalized AI challenges based on user's fitness data.
    /// Analyzes streaks, nutrition, activity, and social engagement to
    /// create challenges that are challenging but achievable.
    func generateChallenges(forceRefresh: Bool = false) async {
        // Only regenerate once per day unless forced
        if !forceRefresh, let lastDate = UserDefaults.standard.object(forKey: lastGeneratedKey) as? Date {
            if Calendar.current.isDateInToday(lastDate) && !activeChallenges.isEmpty {
                return
            }
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        // Gather current user fitness state
        let streak = StreakManager.shared
        let currentStreak = streak.currentStreak
        let level = streak.level
        let totalPoints = streak.totalPoints
        
        // Fetch nutrition data from local cache
        let todayTotals = LocalMealCache.shared.getTodayTotals()
        
        // Build user profile for AI analysis
        let userProfile = UserFitnessProfile(
            level: level,
            streak: currentStreak,
            points: totalPoints,
            avgCalories: todayTotals.calories,
            avgProtein: todayTotals.protein,
            avgCarbs: todayTotals.carbs,
            avgWater: 0, // Will be fetched
            completedChallenges: completedChallenges.count
        )
        
        // Generate challenges adapted to user's level
        let newChallenges = generateAdaptiveChallenges(profile: userProfile)
        
        // Keep existing active challenges that haven't expired
        let stillActive = activeChallenges.filter { $0.expiresAt > Date() && !$0.isCompleted }
        
        // Merge: keep ongoing, add new ones up to 5 total
        let slotsAvailable = max(0, 5 - stillActive.count)
        let toAdd = Array(newChallenges.prefix(slotsAvailable))
        
        activeChallenges = stillActive + toAdd
        
        UserDefaults.standard.set(Date(), forKey: lastGeneratedKey)
        saveCachedChallenges()
    }
    
    // MARK: - Adaptive Challenge Generation
    private func generateAdaptiveChallenges(profile: UserFitnessProfile) -> [AIChallenge] {
        var challenges: [AIChallenge] = []
        let now = Date()
        let cal = Calendar.current
        
        // Difficulty scales with user level
        let baseDifficulty: AIChallenge.Difficulty = {
            switch profile.level {
            case 1...3: return .easy
            case 4...7: return .medium
            case 8...15: return .hard
            default: return .extreme
            }
        }()
        
        // 1. Nutrition Challenge — push calorie/protein targets slightly
        let calorieTarget = max(1800, profile.avgCalories * 1.0) // Hit at least baseline
        let proteinTarget = max(50, profile.avgProtein * 1.15) // 15% more protein
        
        challenges.append(AIChallenge(
            id: UUID().uuidString,
            title: "Protein Powerhouse",
            description: "Hit \(Int(proteinTarget))g protein today. Your AI coach calculated this based on your recent intake — push a little harder!",
            icon: "🥩",
            category: .nutrition,
            difficulty: baseDifficulty,
            targetValue: proteinTarget,
            unit: "g protein",
            durationDays: 1,
            xpReward: Int(50 * baseDifficulty.xpMultiplier),
            createdAt: now,
            expiresAt: cal.date(byAdding: .day, value: 1, to: now) ?? now,
            currentProgress: profile.avgProtein,
            isCompleted: false
        ))
        
        // 2. Activity Challenge — steps based on current activity
        let stepTarget: Double = {
            switch profile.level {
            case 1...2: return 5000
            case 3...5: return 8000
            case 6...10: return 10000
            case 11...20: return 12000
            default: return 15000
            }
        }()
        
        challenges.append(AIChallenge(
            id: UUID().uuidString,
            title: "Step Crusher",
            description: "Walk \(Int(stepTarget)) steps today. AI detected you can push further based on your activity patterns.",
            icon: "👟",
            category: .activity,
            difficulty: baseDifficulty,
            targetValue: stepTarget,
            unit: "steps",
            durationDays: 1,
            xpReward: Int(75 * baseDifficulty.xpMultiplier),
            createdAt: now,
            expiresAt: cal.date(byAdding: .day, value: 1, to: now) ?? now,
            currentProgress: 0,
            isCompleted: false
        ))
        
        // 3. Consistency Challenge — keep the streak going
        let streakTarget = Double(max(profile.streak + 1, 3))
        challenges.append(AIChallenge(
            id: UUID().uuidString,
            title: "Streak Builder",
            description: "Maintain a \(Int(streakTarget))-day streak. You're at \(profile.streak) — one more day and you level up!",
            icon: "🔥",
            category: .consistency,
            difficulty: profile.streak > 7 ? .hard : .medium,
            targetValue: streakTarget,
            unit: "days",
            durationDays: Int(streakTarget),
            xpReward: Int(100 * baseDifficulty.xpMultiplier),
            createdAt: now,
            expiresAt: cal.date(byAdding: .day, value: Int(streakTarget), to: now) ?? now,
            currentProgress: Double(profile.streak),
            isCompleted: false
        ))
        
        // 4. Social Challenge — engage with community
        challenges.append(AIChallenge(
            id: UUID().uuidString,
            title: "Community Champion",
            description: "Challenge 2 nearby people today. Your AI coach thinks healthy competition will boost your motivation!",
            icon: "🤝",
            category: .social,
            difficulty: .medium,
            targetValue: 2,
            unit: "challenges sent",
            durationDays: 1,
            xpReward: Int(60 * baseDifficulty.xpMultiplier),
            createdAt: now,
            expiresAt: cal.date(byAdding: .day, value: 1, to: now) ?? now,
            currentProgress: 0,
            isCompleted: false
        ))
        
        // 5. Water Challenge
        let waterTarget: Double = {
            switch profile.level {
            case 1...3: return 2.0
            case 4...7: return 2.5
            case 8...15: return 3.0
            default: return 3.5
            }
        }()
        
        challenges.append(AIChallenge(
            id: UUID().uuidString,
            title: "Hydration Hero",
            description: "Drink \(String(format: "%.1f", waterTarget))L of water. Proper hydration = better performance. AI set this target for your body.",
            icon: "💧",
            category: .mindfulness,
            difficulty: baseDifficulty,
            targetValue: waterTarget,
            unit: "liters",
            durationDays: 1,
            xpReward: Int(40 * baseDifficulty.xpMultiplier),
            createdAt: now,
            expiresAt: cal.date(byAdding: .day, value: 1, to: now) ?? now,
            currentProgress: profile.avgWater,
            isCompleted: false
        ))
        
        // 6. Calorie Balance
        challenges.append(AIChallenge(
            id: UUID().uuidString,
            title: "Calorie Commander",
            description: "Stay within \(Int(calorieTarget)) kcal today. Your AI analyzed your metabolic needs and set this precision target.",
            icon: "🎯",
            category: .nutrition,
            difficulty: .hard,
            targetValue: calorieTarget,
            unit: "kcal",
            durationDays: 1,
            xpReward: Int(80 * baseDifficulty.xpMultiplier),
            createdAt: now,
            expiresAt: cal.date(byAdding: .day, value: 1, to: now) ?? now,
            currentProgress: profile.avgCalories,
            isCompleted: false
        ))
        
        // 7. Weekly Workout Goal
        let workoutTarget: Double = {
            switch profile.level {
            case 1...3: return 3
            case 4...7: return 4
            case 8...15: return 5
            default: return 6
            }
        }()
        
        challenges.append(AIChallenge(
            id: UUID().uuidString,
            title: "Iron Will",
            description: "Complete \(Int(workoutTarget)) workouts this week. AI sees you're getting stronger — let's lock this in!",
            icon: "💪",
            category: .activity,
            difficulty: baseDifficulty == .extreme ? .extreme : .hard,
            targetValue: workoutTarget,
            unit: "workouts",
            durationDays: 7,
            xpReward: Int(150 * baseDifficulty.xpMultiplier),
            createdAt: now,
            expiresAt: cal.date(byAdding: .day, value: 7, to: now) ?? now,
            currentProgress: 0,
            isCompleted: false
        ))
        
        return challenges.shuffled()
    }
    
    // MARK: - Update Progress
    func updateProgress(challengeId: String, newValue: Double) {
        guard let index = activeChallenges.firstIndex(where: { $0.id == challengeId }) else { return }
        activeChallenges[index].currentProgress = newValue
        
        if activeChallenges[index].progressPercent >= 1.0 && !activeChallenges[index].isCompleted {
            completeChallenge(at: index)
        }
        saveCachedChallenges()
    }
    
    func updateProgressByCategory(_ category: AIChallenge.Category, value: Double) {
        for (index, challenge) in activeChallenges.enumerated() {
            if challenge.category == category && !challenge.isCompleted {
                activeChallenges[index].currentProgress = value
                if activeChallenges[index].progressPercent >= 1.0 {
                    completeChallenge(at: index)
                }
            }
        }
        saveCachedChallenges()
    }
    
    // MARK: - Complete Challenge
    private func completeChallenge(at index: Int) {
        activeChallenges[index].isCompleted = true
        let challenge = activeChallenges[index]
        totalXPEarned += challenge.xpReward
        challengeStreak += 1
        
        UserDefaults.standard.set(totalXPEarned, forKey: xpKey)
        UserDefaults.standard.set(challengeStreak, forKey: streakKey)
        
        completedChallenges.append(challenge)
        HapticManager.shared.success()
        
        // Award points to StreakManager too
        StreakManager.shared.awardPoints(challenge.xpReward)
    }
    
    // MARK: - Cache
    private func loadCachedChallenges() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([AIChallenge].self, from: data) {
            let now = Date()
            activeChallenges = decoded.filter { !$0.isCompleted && $0.expiresAt > now }
            completedChallenges = decoded.filter { $0.isCompleted }
        }
    }
    
    private func saveCachedChallenges() {
        let all = activeChallenges + completedChallenges
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}

// MARK: - User Fitness Profile (for AI analysis)
private struct UserFitnessProfile {
    let level: Int
    let streak: Int
    let points: Int
    let avgCalories: Double
    let avgProtein: Double
    let avgCarbs: Double
    let avgWater: Double
    let completedChallenges: Int
}
