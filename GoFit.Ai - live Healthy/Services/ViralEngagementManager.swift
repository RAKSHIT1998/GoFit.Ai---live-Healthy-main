import Foundation
import SwiftUI

/// Manages viral features, referrals, sharing, and retention mechanics
@MainActor
class ViralEngagementManager: ObservableObject {
    static let shared = ViralEngagementManager()
    
    @Published var referralCode: String = ""
    @Published var referralCount: Int = 0
    @Published var shareStreak: Int = 0
    @Published var dailyShareCompleted: Bool = false
    @Published var weeklyMilestone: String = ""
    
    // MARK: - Cheer Messages Pool (randomized for variety)
    static let cheerMessages: [String] = [
        "🎉👏 Cheering you on! Keep crushing it! 💪🔥",
        "🌟 You're doing amazing! So proud of your progress! 🙌",
        "💪🔥 Beast mode activated! Keep up the incredible work! 🏆",
        "⚡️ Your dedication is inspiring! Let's GO! 🚀",
        "🎯 Crushing goals like a champion! Keep it up! 👑",
        "🌈 Every rep counts, every meal matters. You got this! 💯",
        "🏋️ Stronger every day! Your consistency is 🔥!",
        "💥 BOOM! Nothing can stop you! Keep grinding! 🦾",
        "🌟 Fitness legend in the making! So proud! 🎊",
        "🥳 Celebrating your journey! You're absolutely killing it! 🏅",
        "🔥 Your progress is FIRE! Keep burning bright! ✨",
        "💪 Champions don't quit! And you're a champion! 🏆",
        "🌊 Riding the wave of success! Keep flowing! 🏄",
        "⭐️ Star performer! Your dedication shines! 🌟",
        "🎪 What a show of strength! Bravo! 👏🎭",
        "🦁 Unleash the beast! You're on FIRE today! 🔥",
        "🎸 Rock star energy! Keep rocking your goals! 🤘",
        "🌺 Growing stronger, one day at a time! Beautiful! 🌸",
        "🏔️ Mountain mover! No obstacle too great! ⛰️",
        "🎯 Bullseye! You're hitting every target! 🏹"
    ]
    
    // MARK: - Motivational Share Texts
    static let motivationalShareTexts: [String] = [
        "Just crushed my fitness goals on GoFit.Ai! 💪🔥 Join me! #GoFitAi #FitnessJourney",
        "My AI fitness coach is keeping me on track! 🏆 Try GoFit.Ai! #GoFitAi #HealthyLifestyle",
        "Another day, another milestone! GoFit.Ai makes it easy 📱✨ #GoFitAi",
        "Track. Compete. Transform. GoFit.Ai is a game changer! 🎯 #GoFitAi",
        "My fitness streak is on fire! 🔥 Who's joining me? #GoFitAi #FitnessMotivation",
        "Scanned my meal in 2 seconds and got full nutrition breakdown! 📸🥗 #GoFitAi #MealTracking",
        "Competing with friends makes fitness fun! 🏅 Download GoFit.Ai! #GoFitAi #FitFam",
        "My health data all in one place - AI-powered and beautiful 📊 #GoFitAi",
    ]
    
    // MARK: - Notification Message Pools (for randomization)
    
    static let mealReminderMessages: [(title: String, body: String)] = [
        ("Time for breakfast! 🌅", "Start your day right with a nutritious breakfast. Scan it with GoFit!"),
        ("Fuel up! 🍳", "Your body needs energy. What delicious breakfast are you having?"),
        ("Rise and eat! ☀️", "A healthy breakfast sets the tone for the whole day."),
        ("Good morning, champion! 🏆", "Breakfast is the most important meal. Don't skip it!"),
        ("Morning fuel time! ⛽️", "Power up with a balanced breakfast and log it!"),
        ("Lunch o'clock! 🍱", "Time to refuel midday. What are you eating?"),
        ("Midday power-up! ⚡️", "Keep your energy high with a balanced lunch."),
        ("Lunch break! 🥗", "Take a moment to eat well and log your meal."),
        ("Hunger alert! 🔔", "Your body is calling for lunch. Feed it right!"),
        ("Snack attack! 🍎", "A healthy snack keeps you going. Log it!"),
        ("Afternoon boost! 🚀", "Smart snacking = better performance. What's your pick?"),
        ("Energy dip? 📉", "A healthy snack can turn your afternoon around!"),
        ("Dinner time! 🌙", "End your day with a nourishing dinner."),
        ("Evening meal! 🍽️", "Time for dinner! Make it count and log it."),
        ("Last meal of the day! 🌆", "A balanced dinner for a good night's rest."),
        ("Dinner awaits! 🥘", "Wrap up your nutrition day with a delicious dinner!")
    ]
    
    static let waterReminderMessages: [(title: String, body: String)] = [
        ("Stay Hydrated! 💧", "Time to drink water! Your body will thank you."),
        ("Water break! 🚰", "Hydration is key to performance. Take a sip!"),
        ("Drink up! 💦", "Staying hydrated helps your body function at its best."),
        ("H2O time! 🌊", "Don't forget your water! Every sip counts."),
        ("Hydration check! ✅", "How's your water intake? Time for a refill!"),
        ("Thirsty? 🥤", "Your cells need water to perform. Drink up!"),
        ("Water reminder 💧", "Dehydration hurts performance. Stay on top of it!"),
        ("Sip sip! 🧊", "Ice cold water = instant energy boost. Try it!"),
        ("Hydrate to dominate! 💪", "Water is your secret weapon. Keep drinking!"),
        ("Glass half empty? 🥛", "Fill it up! Hydration = happiness."),
    ]
    
    static let workoutReminderMessages: [(title: String, body: String)] = [
        ("Workout Time! 💪", "Your body will thank you for staying active today."),
        ("Let's move! 🏃", "Even 20 minutes of exercise makes a difference!"),
        ("Get moving! 🔥", "A workout a day keeps the doctor away!"),
        ("Time to sweat! 💦", "Push yourself! You're stronger than you think."),
        ("Exercise o'clock! ⏰", "Your future self will thank you. Let's go!"),
        ("Gym calling! 🏋️", "Your muscles are waiting. Don't leave them hanging!"),
        ("Active time! 🧘", "Move your body, clear your mind. Let's do this!"),
        ("Burn baby burn! 🔥", "Time to torch some calories and feel amazing!"),
        ("Fitness hour! 🎯", "Consistency beats intensity. Show up today!"),
        ("Workout warrior! ⚔️", "Another day, another chance to be stronger!"),
    ]
    
    static let socialEngagementMessages: [(title: String, body: String)] = [
        ("Your friends are active! 👥", "Check what your fitness buddies are up to today!"),
        ("Send some love! 💛", "Cheer on a friend to boost their motivation!"),
        ("Challenge time! 🏆", "Challenge a friend and see who crushes it!"),
        ("Friend update 📬", "Your friends logged their workouts. Send a cheer!"),
        ("Social fitness! 🤝", "Fitness is better with friends. Share your progress!"),
        ("Motivation Monday! 🌟", "Start the week by cheering your fitness crew!"),
        ("Streak check! 🔥", "Share your streak with friends and inspire them!"),
        ("Weekly recap ready! 📊", "Share your weekly achievements with friends!"),
    ]
    
    private init() {
        loadReferralData()
    }
    
    // MARK: - Referral System
    
    func generateReferralCode(userId: String) -> String {
        let code = "GOFIT\(userId.prefix(6).uppercased())"
        referralCode = code
        UserDefaults.standard.set(code, forKey: "referral_code")
        return code
    }
    
    func getShareableInviteLink(userName: String, userId: String) -> String {
        let code = referralCode.isEmpty ? generateReferralCode(userId: userId) : referralCode
        return """
        Hey! 💪 \(userName) wants you to join GoFit.Ai — the #1 AI-powered fitness app!
        
        🔥 AI meal scanning & tracking
        🏆 Compete with friends
        📊 Smart health insights
        🎯 Personalized recommendations
        
        Use code: \(code) for bonus rewards!
        
        Download: https://apps.apple.com/app/gofit-ai
        
        #GoFitAi #FitnessApp
        """
    }
    
    // MARK: - Cheer System
    
    static func randomCheerMessage() -> String {
        cheerMessages.randomElement() ?? cheerMessages[0]
    }
    
    // MARK: - Share Streaks
    
    func recordShare() {
        let today = Calendar.current.startOfDay(for: Date())
        let lastShareDate = UserDefaults.standard.object(forKey: "last_share_date") as? Date
        
        if let lastDate = lastShareDate, Calendar.current.isDate(lastDate, inSameDayAs: today) {
            return // Already shared today
        }
        
        if let lastDate = lastShareDate {
            let daysBetween = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: lastDate), to: today).day ?? 0
            if daysBetween == 1 {
                shareStreak += 1
            } else {
                shareStreak = 1
            }
        } else {
            shareStreak = 1
        }
        
        dailyShareCompleted = true
        UserDefaults.standard.set(today, forKey: "last_share_date")
        UserDefaults.standard.set(shareStreak, forKey: "share_streak")
        
        // Award bonus points for sharing
        StreakManager.shared.awardPoints(15)
    }
    
    // MARK: - Weekly Milestones
    
    func checkWeeklyMilestone() {
        let streak = StreakManager.shared.currentStreak
        let meals = LocalDailyLogStore.shared.getLogsForLastDays(7).reduce(0) { $0 + $1.meals.count }
        
        if streak >= 7 && meals >= 14 {
            weeklyMilestone = "🏆 Perfect Week! 7-day streak + \(meals) meals logged!"
        } else if streak >= 7 {
            weeklyMilestone = "🔥 7-Day Streak Master! Keep the momentum!"
        } else if meals >= 21 {
            weeklyMilestone = "🍽️ Nutrition Champion! \(meals) meals logged this week!"
        } else {
            weeklyMilestone = ""
        }
    }
    
    // MARK: - Persistence
    
    private func loadReferralData() {
        referralCode = UserDefaults.standard.string(forKey: "referral_code") ?? ""
        referralCount = UserDefaults.standard.integer(forKey: "referral_count")
        shareStreak = UserDefaults.standard.integer(forKey: "share_streak")
    }
}
