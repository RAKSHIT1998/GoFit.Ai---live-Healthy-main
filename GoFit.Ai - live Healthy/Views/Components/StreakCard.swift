//
//  StreakCard.swift
//  GoFit.Ai - live Healthy
//
//  Displays user's streak and gamification stats
//

import SwiftUI

struct StreakCard: View {
    @ObservedObject var streakManager = StreakManager.shared
    @State private var showingAchievements = false
    @State private var animateFlame = false
    
    var body: some View {
        VStack(spacing: Design.Spacing.md) {
            // Top row: Streak and Level
            HStack(spacing: Design.Spacing.lg) {
                // Streak
                HStack(spacing: 8) {
                    ZStack {
                        // Flame glow effect
                        if streakManager.currentStreak > 0 {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.orange.opacity(0.3))
                                .blur(radius: 8)
                                .scaleEffect(animateFlame ? 1.2 : 0.9)
                        }
                        
                        Image(systemName: streakManager.currentStreak > 0 ? "flame.fill" : "flame")
                            .font(.system(size: 28))
                            .foregroundColor(streakManager.currentStreak > 0 ? .orange : .gray)
                            .scaleEffect(animateFlame ? 1.1 : 1.0)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(streakManager.currentStreak)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Day Streak")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Level Badge
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Design.Colors.primary, Design.Colors.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Text("\(streakManager.level)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Text("Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Points
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(streakManager.totalPoints)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Design.Colors.primary)
                    Text("Points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress to next level
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Next Level")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(streakManager.pointsToNextLevel) pts to go")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Design.Colors.primaryGradient)
                            .frame(width: geo.size.width * streakManager.levelProgress)
                            .animation(Design.Animation.smooth, value: streakManager.levelProgress)
                    }
                }
                .frame(height: 6)
            }
            
            Divider()
            
            // Achievements preview
            HStack {
                Text("Achievements")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Show recent unlocked achievements
                HStack(spacing: -8) {
                    ForEach(streakManager.unlockedAchievements.suffix(3), id: \.self) { achievement in
                        Circle()
                            .fill(Color.yellow.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text(achievement.emoji)
                                    .font(.system(size: 16))
                            )
                    }
                    
                    if streakManager.unlockedAchievements.count > 3 {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("+\(streakManager.unlockedAchievements.count - 3)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                
                Button {
                    HapticManager.shared.lightTap()
                    showingAchievements = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                animateFlame = true
            }
        }
        .sheet(isPresented: $showingAchievements) {
            AchievementsView()
        }
    }
}

// MARK: - Achievements View
struct AchievementsView: View {
    @ObservedObject var streakManager = StreakManager.shared
    @Environment(\.dismiss) var dismiss
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Design.Spacing.xl) {
                    // Stats header
                    HStack(spacing: Design.Spacing.xl) {
                        StatBadge(value: "\(streakManager.currentStreak)", label: "Current Streak", icon: "flame.fill", color: .orange)
                        StatBadge(value: "\(streakManager.longestStreak)", label: "Best Streak", icon: "trophy.fill", color: .yellow)
                        StatBadge(value: "\(streakManager.level)", label: "Level", icon: "star.fill", color: Design.Colors.primary)
                    }
                    .padding(.horizontal)
                    
                    // All achievements grid
                    VStack(alignment: .leading, spacing: Design.Spacing.md) {
                        Text("All Achievements")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: Design.Spacing.md) {
                            ForEach(AchievementType.allCases, id: \.self) { achievement in
                                AchievementBadge(
                                    achievement: achievement,
                                    isUnlocked: streakManager.unlockedAchievements.contains(achievement)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Daily goals
                    VStack(alignment: .leading, spacing: Design.Spacing.md) {
                        Text("Daily Goals")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        ForEach(DailyGoal.allCases, id: \.self) { goal in
                            DailyGoalRow(
                                goal: goal,
                                isCompleted: streakManager.dailyGoalsCompleted.contains(goal)
                            )
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Design.Colors.background.ignoresSafeArea())
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AchievementBadge: View {
    let achievement: AchievementType
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                if isUnlocked {
                    Text(achievement.emoji)
                        .font(.system(size: 30))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            
            Text(achievement.title)
                .font(.caption2.weight(.medium))
                .foregroundColor(isUnlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
        .opacity(isUnlocked ? 1 : 0.6)
    }
}

struct DailyGoalRow: View {
    let goal: DailyGoal
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: Design.Spacing.md) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Design.Colors.success.opacity(0.15) : Color.gray.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: isCompleted ? "checkmark.circle.fill" : goal.icon)
                    .font(.title3)
                    .foregroundColor(isCompleted ? Design.Colors.success : .gray)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Text(goal.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("+\(goal.points) pts")
                .font(.caption.weight(.semibold))
                .foregroundColor(isCompleted ? Design.Colors.success : .secondary)
        }
        .padding()
        .background(Design.Colors.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Motivational Quote Card
struct MotivationalQuoteCard: View {
    @State private var quote: MotivationalQuote = MotivationalQuote.dailyQuote()
    @State private var animateGradient = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            HStack {
                Image(systemName: "quote.opening")
                    .font(.title2)
                    .foregroundColor(Design.Colors.primary.opacity(0.5))
                Spacer()
            }
            
            Text(quote.text)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundColor(.primary)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Spacer()
                Text("— \(quote.author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Design.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Design.Colors.primary.opacity(0.05),
                            Design.Colors.accent.opacity(0.05)
                        ],
                        startPoint: animateGradient ? .topLeading : .bottomTrailing,
                        endPoint: animateGradient ? .bottomTrailing : .topLeading
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Design.Colors.primary.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}

#Preview {
    VStack {
        StreakCard()
        MotivationalQuoteCard()
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
