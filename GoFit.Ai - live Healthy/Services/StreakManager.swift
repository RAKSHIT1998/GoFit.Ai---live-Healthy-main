//
//  StreakManager.swift
//  GoFit.Ai - live Healthy
//
//  Gamification system for daily streaks and achievements
//

import SwiftUI
import Foundation

@MainActor
class StreakManager: ObservableObject {
    static let shared = StreakManager()
    
    // MARK: - Published Properties
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var totalPoints: Int = 0
    @Published var todayPoints: Int = 0
    @Published var level: Int = 1
    @Published var achievements: [StreakAchievement] = []
    @Published var dailyGoalsCompleted: [DailyGoal] = []
    @Published var showCelebration: Bool = false
    @Published var celebrationMessage: String = ""
    
    // Storage keys
    private let lastActiveKey = "streak_last_active"
    private let currentStreakKey = "streak_current"
    private let longestStreakKey = "streak_longest"
    private let totalPointsKey = "streak_total_points"
    private let todayPointsKey = "streak_today_points"
    private let lastPointsDateKey = "streak_last_points_date"
    private let achievementsKey = "streak_achievements"
    
    // MARK: - Points Values
    struct PointValues {
        static let mealLogged = 10
        static let workoutCompleted = 25
        static let waterGoalMet = 15
        static let calorieGoalMet = 20
        static let dailyLogin = 5
        static let streakBonus = 10 // Per streak day
        static let weeklyStreak = 50
        static let monthlyStreak = 200
        static let perfectDay = 100 // All goals met
    }
    
    private init() {
        loadData()
        checkStreak()
        setupDailyGoals()
    }
    
    // MARK: - Streak Management
    func checkAndUpdateStreak() {
        checkStreak()
    }
    
    func checkStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastActive = UserDefaults.standard.object(forKey: lastActiveKey) as? Date {
            let lastActiveDay = calendar.startOfDay(for: lastActive)
            let daysDifference = calendar.dateComponents([.day], from: lastActiveDay, to: today).day ?? 0
            
            if daysDifference == 0 {
                // Same day, streak continues
                return
            } else if daysDifference == 1 {
                // Consecutive day, increment streak
                currentStreak += 1
                awardPoints(PointValues.dailyLogin + (currentStreak * PointValues.streakBonus / 5))
                
                // Check for streak milestones
                checkStreakMilestones()
            } else {
                // Streak broken
                if currentStreak > 0 {
                    celebrationMessage = "Streak lost! Start fresh today 💪"
                    showCelebration = true
                }
                currentStreak = 1
                awardPoints(PointValues.dailyLogin)
            }
            
            longestStreak = max(longestStreak, currentStreak)
        } else {
            // First time user
            currentStreak = 1
            awardPoints(PointValues.dailyLogin)
        }
        
        UserDefaults.standard.set(today, forKey: lastActiveKey)
        saveData()
    }
    
    private func checkStreakMilestones() {
        switch currentStreak {
        case 7:
            unlockAchievement(.weekWarrior)
            celebrationMessage = "🔥 7-Day Streak! Week Warrior unlocked!"
            showCelebration = true
            awardPoints(PointValues.weeklyStreak)
        case 14:
            unlockAchievement(.twoWeekChampion)
            celebrationMessage = "⚡️ 14-Day Streak! You're unstoppable!"
            showCelebration = true
        case 30:
            unlockAchievement(.monthlyMaster)
            celebrationMessage = "🏆 30-Day Streak! Monthly Master!"
            showCelebration = true
            awardPoints(PointValues.monthlyStreak)
        case 100:
            unlockAchievement(.centurion)
            celebrationMessage = "👑 100-Day Streak! Legendary!"
            showCelebration = true
            awardPoints(500)
        default:
            if currentStreak > 0 && currentStreak % 7 == 0 {
                celebrationMessage = "🔥 \(currentStreak)-Day Streak!"
                showCelebration = true
            }
        }
    }
    
    // MARK: - Points System
    func awardPoints(_ points: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Check if it's a new day
        if let lastPointsDate = UserDefaults.standard.object(forKey: lastPointsDateKey) as? Date {
            let lastDay = calendar.startOfDay(for: lastPointsDate)
            if lastDay != today {
                todayPoints = 0
            }
        }
        
        todayPoints += points
        totalPoints += points
        updateLevel()
        
        UserDefaults.standard.set(today, forKey: lastPointsDateKey)
        saveData()
    }
    
    func logMeal() {
        awardPoints(PointValues.mealLogged)
        checkDailyGoal(.logMeals)
        RetentionManager.shared.recordMeaningfulAction(.mealLogged)
        HapticManager.shared.success()
    }
    
    func completeWorkout() {
        awardPoints(PointValues.workoutCompleted)
        checkDailyGoal(.workout)
        RetentionManager.shared.recordMeaningfulAction(.workoutCompleted)
        HapticManager.shared.success()
    }
    
    func meetWaterGoal() {
        awardPoints(PointValues.waterGoalMet)
        checkDailyGoal(.water)
        unlockAchievement(.hydrationHero)
        RetentionManager.shared.recordMeaningfulAction(.waterGoalMet)
    }
    
    func meetCalorieGoal() {
        awardPoints(PointValues.calorieGoalMet)
        checkDailyGoal(.calories)
    }
    
    private func updateLevel() {
        // Level up every 500 points
        let newLevel = (totalPoints / 500) + 1
        if newLevel > level {
            level = newLevel
            celebrationMessage = "🎉 Level Up! You're now Level \(level)!"
            showCelebration = true
            HapticManager.shared.success()
        }
    }
    
    // MARK: - Achievements
    func unlockAchievement(_ achievement: AchievementType) {
        guard !achievements.contains(where: { $0.type == achievement }) else { return }
        
        let newAchievement = StreakAchievement(type: achievement, unlockedAt: Date())
        achievements.append(newAchievement)
        saveData()
        
        HapticManager.shared.success()
    }
    
    // MARK: - Daily Goals
    private func setupDailyGoals() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Reset daily goals if new day
        if let lastDate = UserDefaults.standard.object(forKey: "daily_goals_date") as? Date {
            if calendar.startOfDay(for: lastDate) != today {
                dailyGoalsCompleted = []
                UserDefaults.standard.set(today, forKey: "daily_goals_date")
            }
        } else {
            UserDefaults.standard.set(today, forKey: "daily_goals_date")
        }
    }
    
    private func checkDailyGoal(_ goal: DailyGoal) {
        if !dailyGoalsCompleted.contains(goal) {
            dailyGoalsCompleted.append(goal)
            
            // Check for perfect day
            if dailyGoalsCompleted.count >= 4 {
                awardPoints(PointValues.perfectDay)
                unlockAchievement(.perfectDay)
                celebrationMessage = "⭐️ Perfect Day! All goals completed!"
                showCelebration = true
            }
        }
    }
    
    // MARK: - Persistence
    private func loadData() {
        currentStreak = UserDefaults.standard.integer(forKey: currentStreakKey)
        longestStreak = UserDefaults.standard.integer(forKey: longestStreakKey)
        totalPoints = UserDefaults.standard.integer(forKey: totalPointsKey)
        todayPoints = UserDefaults.standard.integer(forKey: todayPointsKey)
        level = max(1, (totalPoints / 500) + 1)
        
        if let data = UserDefaults.standard.data(forKey: achievementsKey),
           let decoded = try? JSONDecoder().decode([StreakAchievement].self, from: data) {
            achievements = decoded
        }
    }
    
    private func saveData() {
        UserDefaults.standard.set(currentStreak, forKey: currentStreakKey)
        UserDefaults.standard.set(longestStreak, forKey: longestStreakKey)
        UserDefaults.standard.set(totalPoints, forKey: totalPointsKey)
        UserDefaults.standard.set(todayPoints, forKey: todayPointsKey)
        
        if let data = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(data, forKey: achievementsKey)
        }
    }
    
    // MARK: - Computed Properties
    var streakEmoji: String {
        switch currentStreak {
        case 0: return "🌱"
        case 1...6: return "🔥"
        case 7...13: return "⚡️"
        case 14...29: return "💪"
        case 30...99: return "🏆"
        default: return "👑"
        }
    }
    
    var levelTitle: String {
        switch level {
        case 1: return "Beginner"
        case 2...4: return "Enthusiast"
        case 5...9: return "Dedicated"
        case 10...19: return "Champion"
        case 20...49: return "Master"
        default: return "Legend"
        }
    }
    
    var pointsToNextLevel: Int {
        let nextLevelPoints = level * 500
        return nextLevelPoints - totalPoints
    }
    
    var levelProgress: Double {
        let currentLevelStart = (level - 1) * 500
        let currentLevelEnd = level * 500
        let progress = Double(totalPoints - currentLevelStart) / Double(currentLevelEnd - currentLevelStart)
        return min(1.0, max(0, progress))
    }
}

// MARK: - Models
struct StreakAchievement: Codable, Identifiable {
    let id = UUID()
    let type: AchievementType
    let unlockedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case type, unlockedAt
    }
}

enum AchievementType: String, Codable, CaseIterable {
    case firstMeal = "first_meal"
    case firstWorkout = "first_workout"
    case weekWarrior = "week_warrior"
    case twoWeekChampion = "two_week_champion"
    case monthlyMaster = "monthly_master"
    case centurion = "centurion"
    case hydrationHero = "hydration_hero"
    case perfectDay = "perfect_day"
    case earlyBird = "early_bird"
    case nightOwl = "night_owl"
    case socialButterfly = "social_butterfly"
    case mealPrepper = "meal_prepper"
    
    var title: String {
        switch self {
        case .firstMeal: return "First Bite"
        case .firstWorkout: return "First Rep"
        case .weekWarrior: return "Week Warrior"
        case .twoWeekChampion: return "Two Week Champion"
        case .monthlyMaster: return "Monthly Master"
        case .centurion: return "Centurion"
        case .hydrationHero: return "Hydration Hero"
        case .perfectDay: return "Perfect Day"
        case .earlyBird: return "Early Bird"
        case .nightOwl: return "Night Owl"
        case .socialButterfly: return "Social Butterfly"
        case .mealPrepper: return "Meal Prepper"
        }
    }
    
    var icon: String {
        switch self {
        case .firstMeal: return "fork.knife"
        case .firstWorkout: return "figure.run"
        case .weekWarrior: return "flame.fill"
        case .twoWeekChampion: return "bolt.fill"
        case .monthlyMaster: return "crown.fill"
        case .centurion: return "star.fill"
        case .hydrationHero: return "drop.fill"
        case .perfectDay: return "star.circle.fill"
        case .earlyBird: return "sunrise.fill"
        case .nightOwl: return "moon.stars.fill"
        case .socialButterfly: return "person.2.fill"
        case .mealPrepper: return "list.bullet.clipboard"
        }
    }
    
    var description: String {
        switch self {
        case .firstMeal: return "Log your first meal"
        case .firstWorkout: return "Complete your first workout"
        case .weekWarrior: return "7-day streak"
        case .twoWeekChampion: return "14-day streak"
        case .monthlyMaster: return "30-day streak"
        case .centurion: return "100-day streak"
        case .hydrationHero: return "Meet water goal"
        case .perfectDay: return "Complete all daily goals"
        case .earlyBird: return "Log before 7 AM"
        case .nightOwl: return "Log after 10 PM"
        case .socialButterfly: return "Add 5 friends"
        case .mealPrepper: return "Log 7 days of meals"
        }
    }
}

enum DailyGoal: String, Codable, CaseIterable {
    case logMeals
    case workout
    case water
    case calories
    case steps
    
    var iconName: String {
        switch self {
        case .logMeals: return "fork.knife"
        case .workout: return "figure.run"
        case .water: return "drop.fill"
        case .calories: return "flame.fill"
        case .steps: return "figure.walk"
        }
    }
    
    var displayTitle: String {
        switch self {
        case .logMeals: return "Log Meals"
        case .workout: return "Complete Workout"
        case .water: return "Drink Water"
        case .calories: return "Meet Calorie Goal"
        case .steps: return "Reach Step Goal"
        }
    }
    
    var displayDescription: String {
        switch self {
        case .logMeals: return "Log at least one meal today"
        case .workout: return "Complete any workout"
        case .water: return "Meet your daily water intake"
        case .calories: return "Stay within calorie target"
        case .steps: return "Walk 10,000 steps"
        }
    }
    
    var points: Int {
        switch self {
        case .logMeals: return 10
        case .workout: return 25
        case .water: return 15
        case .calories: return 20
        case .steps: return 20
        }
    }
}

// MARK: - Motivational Quotes
struct MotivationalQuote {
    let text: String
    let author: String
    
    static let quotes: [MotivationalQuote] = [
        MotivationalQuote(text: "The only bad workout is the one that didn't happen.", author: "Unknown"),
        MotivationalQuote(text: "Take care of your body. It's the only place you have to live.", author: "Jim Rohn"),
        MotivationalQuote(text: "Fitness is not about being better than someone else. It's about being better than you used to be.", author: "Khloe Kardashian"),
        MotivationalQuote(text: "The body achieves what the mind believes.", author: "Napoleon Hill"),
        MotivationalQuote(text: "Don't wish for a good body, work for it.", author: "Unknown"),
        MotivationalQuote(text: "Your health is an investment, not an expense.", author: "Unknown"),
        MotivationalQuote(text: "Strive for progress, not perfection.", author: "Unknown"),
        MotivationalQuote(text: "Every workout counts. Every meal matters.", author: "Unknown"),
        MotivationalQuote(text: "Small daily improvements lead to stunning results.", author: "Robin Sharma"),
        MotivationalQuote(text: "Wake up with determination. Go to bed with satisfaction.", author: "Unknown"),
        MotivationalQuote(text: "You don't have to be extreme, just consistent.", author: "Unknown"),
        MotivationalQuote(text: "The secret of getting ahead is getting started.", author: "Mark Twain"),
        MotivationalQuote(text: "Success is the sum of small efforts repeated day in and day out.", author: "Robert Collier"),
        MotivationalQuote(text: "Your future self will thank you.", author: "Unknown"),
        MotivationalQuote(text: "It's not about having time, it's about making time.", author: "Unknown")
    ]
    
    static func dailyQuote() -> MotivationalQuote {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return quotes[dayOfYear % quotes.count]
    }
    
    static func random() -> MotivationalQuote {
        quotes.randomElement() ?? quotes[0]
    }
}
