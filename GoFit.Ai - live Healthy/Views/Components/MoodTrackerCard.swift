//
//  MoodTrackerCard.swift
//  GoFit.Ai - live Healthy
//
//  Quick emoji-based mood tracker that correlates with fitness activity
//

import SwiftUI

// MARK: - Mood Model
enum FitnessMood: String, CaseIterable, Codable {
    case amazing = "amazing"
    case good = "good"
    case okay = "okay"
    case tired = "tired"
    case stressed = "stressed"
    
    var emoji: String {
        switch self {
        case .amazing: return "🤩"
        case .good: return "😊"
        case .okay: return "😐"
        case .tired: return "😴"
        case .stressed: return "😤"
        }
    }
    
    var label: String {
        switch self {
        case .amazing: return "Amazing!"
        case .good: return "Good"
        case .okay: return "Okay"
        case .tired: return "Tired"
        case .stressed: return "Stressed"
        }
    }
    
    var color: Color {
        switch self {
        case .amazing: return .yellow
        case .good: return .green
        case .okay: return .orange
        case .tired: return .purple
        case .stressed: return .red
        }
    }
    
    var motivationalMessage: String {
        switch self {
        case .amazing: return "Keep that energy going! You're unstoppable! 🚀"
        case .good: return "Great vibes! A workout will make it even better! 💪"
        case .okay: return "A short walk can boost your mood by 50%! 🌤️"
        case .tired: return "Rest is important too! Try some gentle stretching 🧘"
        case .stressed: return "Deep breaths! Even 5 min of exercise reduces stress 🌊"
        }
    }
    
    var suggestedAction: String {
        switch self {
        case .amazing: return "Try a high-intensity workout! 🔥"
        case .good: return "Perfect time for a balanced workout!"
        case .okay: return "A brisk walk could lift your spirits!"
        case .tired: return "Light yoga or stretching recommended"
        case .stressed: return "Try meditation or a calm walk"
        }
    }
}

// MARK: - Mood History Entry
struct MoodEntry: Codable, Identifiable {
    let id: String
    let mood: FitnessMood
    let date: Date
    let note: String?
    
    init(mood: FitnessMood, note: String? = nil) {
        self.id = UUID().uuidString
        self.mood = mood
        self.date = Date()
        self.note = note
    }
}

// MARK: - Mood Manager
@MainActor
class MoodManager: ObservableObject {
    static let shared = MoodManager()
    
    @Published var todayMood: FitnessMood? = nil
    @Published var moodHistory: [MoodEntry] = []
    @Published var showMoodPicker = true
    @Published var weeklyMoodSummary: [FitnessMood: Int] = [:]
    
    private let moodHistoryKey = "mood_history"
    private let todayMoodKey = "today_mood_date"
    
    private init() {
        loadMoodHistory()
        checkTodayMood()
    }
    
    func logMood(_ mood: FitnessMood, note: String? = nil) {
        let entry = MoodEntry(mood: mood, note: note)
        moodHistory.insert(entry, at: 0)
        todayMood = mood
        showMoodPicker = false
        
        // Save
        let today = Calendar.current.startOfDay(for: Date())
        UserDefaults.standard.set(today, forKey: todayMoodKey)
        saveMoodHistory()
        
        // Award XP for logging mood
        RewardEngine.shared.awardXP(5, reason: "Mood logged! \(mood.emoji)")
    }
    
    func checkTodayMood() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastMoodDate = UserDefaults.standard.object(forKey: todayMoodKey) as? Date {
            let lastDay = calendar.startOfDay(for: lastMoodDate)
            if lastDay == today {
                // Already logged today
                showMoodPicker = false
                todayMood = moodHistory.first(where: {
                    calendar.isDateInToday($0.date)
                })?.mood
            } else {
                showMoodPicker = true
                todayMood = nil
            }
        } else {
            showMoodPicker = true
        }
        
        calculateWeeklySummary()
    }
    
    private func calculateWeeklySummary() {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thisWeek = moodHistory.filter { $0.date >= weekAgo }
        
        var summary: [FitnessMood: Int] = [:]
        for entry in thisWeek {
            summary[entry.mood, default: 0] += 1
        }
        weeklyMoodSummary = summary
    }
    
    private func loadMoodHistory() {
        if let data = UserDefaults.standard.data(forKey: moodHistoryKey),
           let decoded = try? JSONDecoder().decode([MoodEntry].self, from: data) {
            // Keep last 30 days only
            let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            moodHistory = decoded.filter { $0.date >= thirtyDaysAgo }
        }
    }
    
    private func saveMoodHistory() {
        if let data = try? JSONEncoder().encode(moodHistory) {
            UserDefaults.standard.set(data, forKey: moodHistoryKey)
        }
    }
}

// MARK: - Mood Tracker Card (Dashboard)
struct MoodTrackerCard: View {
    @ObservedObject var manager = MoodManager.shared
    @State private var selectedMood: FitnessMood? = nil
    @State private var showMotivation = false
    @State private var emojiScales: [CGFloat] = Array(repeating: 0, count: 5)
    @State private var bounceSelected = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "face.smiling.inverse")
                    .foregroundColor(.yellow)
                    .font(.title3)
                
                Text("How are you feeling?")
                    .font(Design.Typography.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if manager.todayMood != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Design.Colors.primary)
                        .font(.subheadline)
                }
            }
            
            if manager.showMoodPicker {
                // Mood selection row
                HStack(spacing: Design.Spacing.sm) {
                    ForEach(Array(FitnessMood.allCases.enumerated()), id: \.element) { index, mood in
                        Button {
                            HapticManager.shared.mediumTap()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                selectedMood = mood
                                bounceSelected = true
                            }
                            
                            // Auto-log after brief delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.spring()) {
                                    manager.logMood(mood)
                                    showMotivation = true
                                }
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text(mood.emoji)
                                    .font(.system(size: selectedMood == mood ? 36 : 30))
                                    .scaleEffect(emojiScales[index])
                                    .scaleEffect(selectedMood == mood && bounceSelected ? 1.2 : 1.0)
                                
                                Text(mood.label)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                                    .foregroundColor(selectedMood == mood ? mood.color : .secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedMood == mood ? mood.color.opacity(0.15) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onAppear {
                    // Stagger emoji appearance
                    for i in 0..<5 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                                emojiScales[i] = 1.0
                            }
                        }
                    }
                }
            } else if let mood = manager.todayMood {
                // Today's mood display with motivation
                VStack(spacing: Design.Spacing.sm) {
                    HStack(spacing: 12) {
                        Text(mood.emoji)
                            .font(.system(size: 40))
                            .floating(amount: 3, duration: 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Feeling \(mood.label.lowercased()) today")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            
                            Text(mood.motivationalMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    // Suggested action pill
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(Design.Colors.primary)
                        Text(mood.suggestedAction)
                            .font(.caption)
                            .foregroundColor(Design.Colors.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Design.Colors.primary.opacity(0.1))
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Weekly mood dots
                    if !manager.weeklyMoodSummary.isEmpty {
                        HStack(spacing: 4) {
                            Text("This week:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            ForEach(manager.moodHistory.prefix(7).reversed()) { entry in
                                Text(entry.mood.emoji)
                                    .font(.system(size: 14))
                            }
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
}
