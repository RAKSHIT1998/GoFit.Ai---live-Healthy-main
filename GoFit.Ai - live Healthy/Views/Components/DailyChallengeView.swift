//
//  DailyChallengeView.swift
//  GoFit.Ai - live Healthy
//
//  Daily challenges to keep users engaged
//

import SwiftUI

// MARK: - Daily Challenge Model
struct DailyChallenge: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let targetValue: Double
    let unit: String
    let pointsReward: Int
    let type: ChallengeType
    var currentProgress: Double
    
    enum ChallengeType: String, Codable {
        case steps
        case water
        case meals
        case workout
        case calories
        case protein
    }
    
    var progress: Double {
        min(currentProgress / targetValue, 1.0)
    }
    
    var isCompleted: Bool {
        currentProgress >= targetValue
    }
    
    static var todaysChallenges: [DailyChallenge] {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: Date())
        
        // Different challenges for different days
        switch dayOfWeek {
        case 1: // Sunday - Rest day challenges
            return [
                DailyChallenge(id: "sun1", title: "Hydration Hero", description: "Drink 8 glasses of water", icon: "drop.fill", targetValue: 2000, unit: "ml", pointsReward: 30, type: .water, currentProgress: 0),
                DailyChallenge(id: "sun2", title: "Mindful Meals", description: "Log 3 healthy meals", icon: "fork.knife", targetValue: 3, unit: "meals", pointsReward: 40, type: .meals, currentProgress: 0),
                DailyChallenge(id: "sun3", title: "Gentle Steps", description: "Take 5,000 steps", icon: "figure.walk", targetValue: 5000, unit: "steps", pointsReward: 25, type: .steps, currentProgress: 0)
            ]
        case 2, 4, 6: // Mon, Wed, Fri - Active days
            return [
                DailyChallenge(id: "active1", title: "Step Master", description: "Walk 10,000 steps", icon: "figure.walk", targetValue: 10000, unit: "steps", pointsReward: 50, type: .steps, currentProgress: 0),
                DailyChallenge(id: "active2", title: "Workout Warrior", description: "Complete a workout", icon: "flame.fill", targetValue: 1, unit: "workout", pointsReward: 40, type: .workout, currentProgress: 0),
                DailyChallenge(id: "active3", title: "Protein Power", description: "Hit 80g of protein", icon: "bolt.fill", targetValue: 80, unit: "g", pointsReward: 35, type: .protein, currentProgress: 0),
                DailyChallenge(id: "active4", title: "Stay Hydrated", description: "Drink 2.5L of water", icon: "drop.fill", targetValue: 2500, unit: "ml", pointsReward: 30, type: .water, currentProgress: 0)
            ]
        default: // Tue, Thu, Sat - Moderate days
            return [
                DailyChallenge(id: "mod1", title: "Daily Walker", description: "Walk 7,500 steps", icon: "figure.walk", targetValue: 7500, unit: "steps", pointsReward: 35, type: .steps, currentProgress: 0),
                DailyChallenge(id: "mod2", title: "Meal Logger", description: "Log all 3 meals", icon: "fork.knife", targetValue: 3, unit: "meals", pointsReward: 30, type: .meals, currentProgress: 0),
                DailyChallenge(id: "mod3", title: "Calorie Control", description: "Stay under 2000 cal", icon: "flame", targetValue: 2000, unit: "cal", pointsReward: 40, type: .calories, currentProgress: 0),
                DailyChallenge(id: "mod4", title: "Water Goal", description: "Drink 2L of water", icon: "drop.fill", targetValue: 2000, unit: "ml", pointsReward: 25, type: .water, currentProgress: 0)
            ]
        }
    }
}

// MARK: - Daily Challenge Manager
class DailyChallengeManager: ObservableObject {
    static let shared = DailyChallengeManager()
    
    @Published var challenges: [DailyChallenge] = []
    @Published var completedToday: Int = 0
    
    private let userDefaults = UserDefaults.standard
    private let challengesKey = "dailyChallenges"
    private let lastUpdateKey = "challengesLastUpdate"
    
    private init() {
        loadChallenges()
    }
    
    func loadChallenges() {
        // Check if we need new challenges (new day)
        if shouldResetChallenges() {
            challenges = DailyChallenge.todaysChallenges
            saveChallenges()
        } else if let data = userDefaults.data(forKey: challengesKey),
                  let saved = try? JSONDecoder().decode([DailyChallenge].self, from: data) {
            challenges = saved
        } else {
            challenges = DailyChallenge.todaysChallenges
        }
        
        updateCompletedCount()
    }
    
    private func shouldResetChallenges() -> Bool {
        guard let lastUpdate = userDefaults.object(forKey: lastUpdateKey) as? Date else {
            return true
        }
        return !Calendar.current.isDateInToday(lastUpdate)
    }
    
    private func saveChallenges() {
        if let data = try? JSONEncoder().encode(challenges) {
            userDefaults.set(data, forKey: challengesKey)
            userDefaults.set(Date(), forKey: lastUpdateKey)
        }
    }
    
    func updateProgress(for type: DailyChallenge.ChallengeType, value: Double) {
        for i in challenges.indices where challenges[i].type == type {
            challenges[i].currentProgress = value
            
            // Check if just completed
            if challenges[i].isCompleted {
                // Award points
                let points = challenges[i].pointsReward
                Task { @MainActor in
                    StreakManager.shared.awardPoints(points)
                }
            }
        }
        saveChallenges()
        updateCompletedCount()
    }
    
    private func updateCompletedCount() {
        completedToday = challenges.filter { $0.isCompleted }.count
    }
    
    var totalPoints: Int {
        challenges.filter { $0.isCompleted }.reduce(0) { $0 + $1.pointsReward }
    }
    
    var overallProgress: Double {
        guard !challenges.isEmpty else { return 0 }
        return Double(completedToday) / Double(challenges.count)
    }
}

// MARK: - Daily Challenge Card View
struct DailyChallengeCard: View {
    @ObservedObject var manager = DailyChallengeManager.shared
    @State private var showingAllChallenges = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Challenges")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("\(manager.completedToday)/\(manager.challenges.count) completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Overall progress ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0, to: manager.overallProgress)
                        .stroke(Design.Colors.primaryGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(manager.overallProgress * 100))%")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(Design.Colors.primary)
                }
            }
            
            // Preview of first 2 challenges
            ForEach(manager.challenges.prefix(2)) { challenge in
                ChallengeRow(challenge: challenge)
            }
            
            // See all button
            if manager.challenges.count > 2 {
                Button {
                    HapticManager.shared.lightTap()
                    showingAllChallenges = true
                } label: {
                    HStack {
                        Text("See All Challenges")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(Design.Colors.primary)
                    .padding(.top, 4)
                }
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        .sheet(isPresented: $showingAllChallenges) {
            AllChallengesView()
        }
    }
}

struct ChallengeRow: View {
    let challenge: DailyChallenge
    
    var body: some View {
        HStack(spacing: Design.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(challenge.isCompleted ? Design.Colors.success.opacity(0.15) : Design.Colors.primary.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                if challenge.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Design.Colors.success)
                } else {
                    Image(systemName: challenge.icon)
                        .font(.system(size: 16))
                        .foregroundColor(Design.Colors.primary)
                }
            }
            
            // Title and progress
            VStack(alignment: .leading, spacing: 4) {
                Text(challenge.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .strikethrough(challenge.isCompleted, color: .secondary)
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(challenge.isCompleted ? Design.Colors.success : Design.Colors.primary)
                            .frame(width: geo.size.width * challenge.progress)
                    }
                }
                .frame(height: 4)
            }
            
            // Points
            Text("+\(challenge.pointsReward)")
                .font(.caption.weight(.semibold))
                .foregroundColor(challenge.isCompleted ? Design.Colors.success : .secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - All Challenges View
struct AllChallengesView: View {
    @ObservedObject var manager = DailyChallengeManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Design.Spacing.lg) {
                    // Summary card
                    VStack(spacing: Design.Spacing.md) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Today's Progress")
                                    .font(.headline)
                                Text("\(manager.completedToday) of \(manager.challenges.count) challenges")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Big progress ring
                            ZStack {
                                Circle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                                    .frame(width: 80, height: 80)
                                
                                Circle()
                                    .trim(from: 0, to: manager.overallProgress)
                                    .stroke(Design.Colors.primaryGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .frame(width: 80, height: 80)
                                    .rotationEffect(.degrees(-90))
                                
                                VStack(spacing: 0) {
                                    Text("\(Int(manager.overallProgress * 100))%")
                                        .font(.title3.weight(.bold))
                                    Text("done")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Label("\(manager.totalPoints) pts earned", systemImage: "star.fill")
                                .font(.subheadline)
                                .foregroundColor(Design.Colors.primary)
                            
                            Spacer()
                            
                            let remaining = manager.challenges.filter { !$0.isCompleted }.reduce(0) { $0 + $1.pointsReward }
                            Text("\(remaining) pts available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Design.Colors.cardBackground)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // All challenges
                    VStack(alignment: .leading, spacing: Design.Spacing.md) {
                        Text("All Challenges")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(manager.challenges) { challenge in
                            DetailedChallengeRow(challenge: challenge)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Design.Colors.background.ignoresSafeArea())
            .navigationTitle("Daily Challenges")
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

struct DetailedChallengeRow: View {
    let challenge: DailyChallenge
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            HStack {
                // Icon
                ZStack {
                    Circle()
                        .fill(challenge.isCompleted ? Design.Colors.success.opacity(0.15) : Design.Colors.primary.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    if challenge.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Design.Colors.success)
                    } else {
                        Image(systemName: challenge.icon)
                            .font(.title3)
                            .foregroundColor(Design.Colors.primary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.title)
                        .font(.headline)
                        .foregroundColor(challenge.isCompleted ? .secondary : .primary)
                        .strikethrough(challenge.isCompleted)
                    
                    Text(challenge.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("+\(challenge.pointsReward)")
                        .font(.headline)
                        .foregroundColor(challenge.isCompleted ? Design.Colors.success : Design.Colors.primary)
                    Text("pts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(challenge.isCompleted ? Design.Colors.success : Design.Colors.primaryGradient)
                            .frame(width: geo.size.width * challenge.progress)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("\(Int(challenge.currentProgress)) \(challenge.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("/ \(Int(challenge.targetValue)) \(challenge.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Design.Colors.cardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    VStack {
        DailyChallengeCard()
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
