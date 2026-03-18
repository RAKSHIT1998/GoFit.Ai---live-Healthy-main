//
//  WeeklyRecapCard.swift
//  GoFit.Ai - live Healthy
//
//  Animated weekly progress celebration summary
//

import SwiftUI

// MARK: - Weekly Recap Card
struct WeeklyRecapCard: View {
    @ObservedObject var streakManager = StreakManager.shared
    @State private var showRecap = false
    @State private var animateBars = false
    @State private var showingFullRecap = false
    
    // Sample weekly data (in production this would be fetched)
    private var weekdayLabels: [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        let calendar = Calendar.current
        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            return formatter.string(from: date)
        }
    }
    
    // Simulated daily XP based on streakManager data
    private var weeklyXP: [CGFloat] {
        let baseXP = CGFloat(streakManager.todayPoints)
        return (0..<7).map { i in
            if i == 6 { return baseXP } // Today
            return CGFloat.random(in: max(0, baseXP * 0.3)...max(20, baseXP * 1.2))
        }
    }
    
    private var maxXP: CGFloat {
        weeklyXP.max() ?? 100
    }
    
    var body: some View {
        Button {
            HapticManager.shared.lightTap()
            showingFullRecap = true
        } label: {
            VStack(alignment: .leading, spacing: Design.Spacing.md) {
                // Header
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(Design.Colors.primary)
                            .font(.subheadline)
                        
                        Text("Weekly Progress")
                            .font(Design.Typography.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Total XP this week
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("\(Int(weeklyXP.reduce(0, +))) XP")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(8)
                }
                
                // Mini bar chart
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<7, id: \.self) { index in
                        VStack(spacing: 4) {
                            // Bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    index == 6 ?
                                    LinearGradient(colors: [Design.Colors.primary, Design.Colors.primaryLight], startPoint: .bottom, endPoint: .top) :
                                        LinearGradient(colors: [Design.Colors.primary.opacity(0.4), Design.Colors.primary.opacity(0.2)], startPoint: .bottom, endPoint: .top)
                                )
                                .frame(
                                    height: animateBars ?
                                    max(8, (weeklyXP[index] / max(maxXP, 1)) * 50) : 4
                                )
                                .animation(
                                    .spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.05),
                                    value: animateBars
                                )
                            
                            // Day label
                            Text(weekdayLabels[index])
                                .font(.system(size: 9, weight: index == 6 ? .bold : .regular, design: .rounded))
                                .foregroundColor(index == 6 ? Design.Colors.primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 70)
                
                // Quick stats row
                HStack(spacing: Design.Spacing.md) {
                    WeeklyStatPill(icon: "flame.fill", value: "\(streakManager.currentStreak)", label: "Streak", color: .orange)
                    WeeklyStatPill(icon: "star.fill", value: "Lv.\(streakManager.level)", label: streakManager.levelTitle, color: Design.Colors.primary)
                    WeeklyStatPill(icon: "trophy.fill", value: "\(streakManager.achievements.count)", label: "Badges", color: .yellow)
                }
            }
            .padding(Design.Spacing.lg)
            .background(Design.Colors.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animateBars = true
            }
        }
        .sheet(isPresented: $showingFullRecap) {
            WeeklyRecapDetailView()
        }
    }
}

// MARK: - Weekly Stat Pill
struct WeeklyStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(label)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Weekly Recap Detail View
struct WeeklyRecapDetailView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var streakManager = StreakManager.shared
    @State private var showContent = false
    @State private var confettiTrigger = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Design.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Design.Spacing.xl) {
                        // Hero section
                        VStack(spacing: Design.Spacing.md) {
                            Text("🎉")
                                .font(.system(size: 60))
                                .scaleEffect(showContent ? 1.0 : 0.3)
                                .animation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.2), value: showContent)
                            
                            Text("Your Week in Review")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut.delay(0.4), value: showContent)
                            
                            Text(weekDateRange())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .opacity(showContent ? 1 : 0)
                                .animation(.easeOut.delay(0.5), value: showContent)
                        }
                        .padding(.top, Design.Spacing.xl)
                        
                        // Stats grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Design.Spacing.md) {
                            RecapStatCard(
                                emoji: "🔥",
                                value: "\(streakManager.currentStreak)",
                                label: "Day Streak",
                                subtitle: streakManager.currentStreak >= 7 ? "On fire!" : "Keep going!",
                                color: .orange,
                                delay: 0.6
                            )
                            
                            RecapStatCard(
                                emoji: "⭐️",
                                value: "\(streakManager.totalPoints)",
                                label: "Total XP",
                                subtitle: "Level \(streakManager.level) \(streakManager.levelTitle)",
                                color: Design.Colors.primary,
                                delay: 0.7
                            )
                            
                            RecapStatCard(
                                emoji: "🏆",
                                value: "\(streakManager.achievements.count)",
                                label: "Achievements",
                                subtitle: "\(AchievementType.allCases.count - streakManager.achievements.count) left to unlock",
                                color: .yellow,
                                delay: 0.8
                            )
                            
                            RecapStatCard(
                                emoji: "💪",
                                value: "\(streakManager.todayPoints)",
                                label: "Today's XP",
                                subtitle: "Keep earning!",
                                color: .blue,
                                delay: 0.9
                            )
                        }
                        .padding(.horizontal)
                        
                        // Motivational message
                        VStack(spacing: Design.Spacing.sm) {
                            Text(weeklyMotivation())
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Text("Every day you show up is a win. 🌟")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(Design.Spacing.lg)
                        .background(Design.Colors.cardBackground)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut.delay(1.0), value: showContent)
                        
                        // Share button
                        Button {
                            HapticManager.shared.mediumTap()
                            confettiTrigger = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share My Progress")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Design.Colors.primaryGradient)
                            .cornerRadius(16)
                        }
                        .padding(.horizontal)
                        .opacity(showContent ? 1 : 0)
                        .animation(.easeOut.delay(1.1), value: showContent)
                    }
                    .padding(.bottom, Design.Spacing.xl)
                }
                
                if confettiTrigger {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Design.Colors.primary)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showContent = true
                }
            }
        }
    }
    
    private func weekDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -6, to: end) ?? end
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    private func weeklyMotivation() -> String {
        if streakManager.currentStreak >= 30 { return "You're a fitness LEGEND! 👑" }
        if streakManager.currentStreak >= 14 { return "Two weeks strong! Unstoppable! ⚡️" }
        if streakManager.currentStreak >= 7 { return "Week warrior mode activated! 🔥" }
        if streakManager.currentStreak >= 3 { return "Building momentum! Keep it up! 💪" }
        return "Every journey starts with day 1! 🌱"
    }
}

// MARK: - Recap Stat Card
struct RecapStatCard: View {
    let emoji: String
    let value: String
    let label: String
    let subtitle: String
    let color: Color
    let delay: Double
    
    @State private var show = false
    
    var body: some View {
        VStack(spacing: Design.Spacing.sm) {
            Text(emoji)
                .font(.system(size: 36))
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .scaleEffect(show ? 1.0 : 0.7)
        .opacity(show ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(delay)) {
                show = true
            }
        }
    }
}
