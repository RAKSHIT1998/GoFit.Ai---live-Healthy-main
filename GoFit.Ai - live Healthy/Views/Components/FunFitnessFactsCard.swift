//
//  FunFitnessFactsCard.swift
//  GoFit.Ai - live Healthy
//
//  Rotating fun/surprising fitness facts with animations
//

import SwiftUI

// MARK: - Fun Fitness Fact
struct FitnessFact: Identifiable {
    let id = UUID()
    let emoji: String
    let fact: String
    let category: FactCategory
    
    enum FactCategory: String, CaseIterable {
        case nutrition = "Nutrition"
        case exercise = "Exercise"
        case body = "Body"
        case mindBlowing = "Mind-Blowing"
        case motivation = "Motivation"
        
        var color: Color {
            switch self {
            case .nutrition: return .green
            case .exercise: return .orange
            case .body: return .blue
            case .mindBlowing: return .purple
            case .motivation: return .yellow
            }
        }
        
        var icon: String {
            switch self {
            case .nutrition: return "leaf.fill"
            case .exercise: return "figure.run"
            case .body: return "heart.fill"
            case .mindBlowing: return "brain.head.profile"
            case .motivation: return "star.fill"
            }
        }
    }
    
    static let allFacts: [FitnessFact] = [
        // Nutrition
        FitnessFact(emoji: "🥑", fact: "Avocados have more potassium than bananas! One avocado has 975mg vs banana's 422mg.", category: .nutrition),
        FitnessFact(emoji: "🍫", fact: "Dark chocolate can improve your workout performance by increasing blood flow by up to 30%!", category: .nutrition),
        FitnessFact(emoji: "🥚", fact: "Eggs contain all 9 essential amino acids, making them a complete protein source!", category: .nutrition),
        FitnessFact(emoji: "🍌", fact: "A banana is about 75% water! Staying hydrated has never been so tasty.", category: .nutrition),
        FitnessFact(emoji: "🫐", fact: "Blueberries can improve memory and reduce muscle soreness after workouts by 13%!", category: .nutrition),
        FitnessFact(emoji: "☕", fact: "Caffeine can boost your metabolism by 3-11% and fat burning by up to 29%!", category: .nutrition),
        FitnessFact(emoji: "🥜", fact: "Almonds contain more calcium than any other nut! Great for strong bones.", category: .nutrition),
        FitnessFact(emoji: "🍉", fact: "Watermelon is 92% water and can help reduce muscle soreness post-workout!", category: .nutrition),
        
        // Exercise
        FitnessFact(emoji: "🏃", fact: "Running just 5 minutes a day can extend your life by up to 3 years!", category: .exercise),
        FitnessFact(emoji: "💪", fact: "Your muscles are 3x more efficient at burning calories than fat, even at rest!", category: .exercise),
        FitnessFact(emoji: "🚶", fact: "Walking 10,000 steps burns approximately 300-400 calories. Every step counts!", category: .exercise),
        FitnessFact(emoji: "🧘", fact: "Just 10 minutes of yoga can reduce cortisol (stress hormone) by 25%!", category: .exercise),
        FitnessFact(emoji: "🏊", fact: "Swimming burns up to 500 calories per hour while being easy on your joints!", category: .exercise),
        FitnessFact(emoji: "🤸", fact: "Laughing for 15 minutes burns approximately 40 calories. Gym + comedy = gains!", category: .exercise),
        FitnessFact(emoji: "🎵", fact: "Listening to music while exercising can improve performance by up to 15%!", category: .exercise),
        FitnessFact(emoji: "🌅", fact: "Morning workouts can boost your metabolism for 14+ hours throughout the day!", category: .exercise),
        
        // Body
        FitnessFact(emoji: "❤️", fact: "Your heart beats about 100,000 times per day, pumping 2,000 gallons of blood!", category: .body),
        FitnessFact(emoji: "🧠", fact: "Exercise increases brain cell production! Your hippocampus grows with cardio.", category: .body),
        FitnessFact(emoji: "🦴", fact: "Your skeleton completely renews itself every 10 years. Feed it calcium!", category: .body),
        FitnessFact(emoji: "💧", fact: "Your body is 60% water. Even 2% dehydration can decrease performance by 25%!", category: .body),
        FitnessFact(emoji: "🫁", fact: "Your lungs process about 2,100 gallons of air every day!", category: .body),
        FitnessFact(emoji: "🔬", fact: "Your body produces 25 million new cells every second. Fuel them right!", category: .body),
        
        // Mind-Blowing
        FitnessFact(emoji: "🌍", fact: "If you walked non-stop, it would take 347 days to walk around the Earth!", category: .mindBlowing),
        FitnessFact(emoji: "⚡️", fact: "The human body generates enough electricity to power a 100-watt light bulb!", category: .mindBlowing),
        FitnessFact(emoji: "🏋️", fact: "The strongest muscle in your body relative to size? Your tongue!", category: .mindBlowing),
        FitnessFact(emoji: "🦷", fact: "Your jaw muscle can exert 200 pounds of force. Strongest bite in the body!", category: .mindBlowing),
        FitnessFact(emoji: "👃", fact: "Your nose can detect over 1 trillion different scents. Smell those gains!", category: .mindBlowing),
        
        // Motivation
        FitnessFact(emoji: "🏆", fact: "It takes 21 days to build a habit but only 66 days to make it automatic. Keep going!", category: .motivation),
        FitnessFact(emoji: "📈", fact: "People who track their food eat 15% less calories. You're already winning! 🎉", category: .motivation),
        FitnessFact(emoji: "🤝", fact: "Working out with a friend increases exercise time by 200%! Share GoFit!", category: .motivation),
        FitnessFact(emoji: "😊", fact: "Exercise releases endorphins that make you happier for up to 12 hours after!", category: .motivation),
        FitnessFact(emoji: "🎯", fact: "Setting specific goals makes you 42% more likely to achieve them!", category: .motivation),
    ]
    
    static func randomFact() -> FitnessFact {
        allFacts.randomElement() ?? allFacts[0]
    }
    
    static func dailyFact() -> FitnessFact {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return allFacts[dayOfYear % allFacts.count]
    }
}

// MARK: - Fun Facts Card
struct FunFitnessFactsCard: View {
    @State private var currentFact: FitnessFact = FitnessFact.dailyFact()
    @State private var isFlipped = false
    @State private var emojiFloat = false
    @State private var showNewFact = false
    @State private var cardRotation: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                HapticManager.shared.lightTap()
                shuffleFact()
            } label: {
                VStack(spacing: Design.Spacing.md) {
                    // Header with category
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.subheadline)
                            
                            Text("Did You Know?")
                                .font(Design.Typography.headline)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        // Category pill
                        HStack(spacing: 4) {
                            Image(systemName: currentFact.category.icon)
                                .font(.caption2)
                            Text(currentFact.category.rawValue)
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundColor(currentFact.category.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(currentFact.category.color.opacity(0.12))
                        .cornerRadius(8)
                    }
                    
                    // Fact content
                    HStack(alignment: .top, spacing: Design.Spacing.md) {
                        // Big emoji
                        Text(currentFact.emoji)
                            .font(.system(size: 44))
                            .offset(y: emojiFloat ? -4 : 4)
                            .animation(
                                .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                value: emojiFloat
                            )
                        
                        // Fact text
                        Text(currentFact.fact)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.primary.opacity(0.85))
                            .multilineTextAlignment(.leading)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Tap to shuffle hint
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                        Text("Tap for another fun fact!")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(Design.Spacing.lg)
                .background(
                    ZStack {
                        Design.Colors.cardBackground
                        
                        // Subtle gradient accent
                        LinearGradient(
                            colors: [currentFact.category.color.opacity(0.05), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                )
                .cornerRadius(16)
                .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
                .rotation3DEffect(.degrees(cardRotation), axis: (x: 0, y: 1, z: 0))
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            emojiFloat = true
        }
    }
    
    private func shuffleFact() {
        // Card flip animation
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            cardRotation = 90
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentFact = FitnessFact.randomFact()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                cardRotation = 0
            }
        }
    }
}
