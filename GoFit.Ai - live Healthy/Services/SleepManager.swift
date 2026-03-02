//
//  SleepManager.swift
//  GoFit.Ai - live Healthy
//
//  Manages sleep tracking data and analysis
//

import Foundation
import HealthKit
import SwiftUI

// MARK: - Sleep Entry Model
struct SleepEntry: Identifiable, Codable {
    let id: String
    var bedtime: Date
    var wakeTime: Date
    var quality: SleepQuality
    var notes: String?
    var mood: SleepMood?
    let createdAt: Date
    
    var duration: TimeInterval {
        wakeTime.timeIntervalSince(bedtime)
    }
    
    var durationHours: Double {
        duration / 3600
    }
    
    var durationFormatted: String {
        let hours = Int(durationHours)
        let minutes = Int((durationHours - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }
    
    init(id: String = UUID().uuidString, bedtime: Date, wakeTime: Date, quality: SleepQuality, notes: String? = nil, mood: SleepMood? = nil) {
        self.id = id
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.quality = quality
        self.notes = notes
        self.mood = mood
        self.createdAt = Date()
    }
}

enum SleepQuality: Int, Codable, CaseIterable {
    case poor = 1
    case fair = 2
    case good = 3
    case excellent = 4
    
    var label: String {
        switch self {
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
    
    var emoji: String {
        switch self {
        case .poor: return "😴"
        case .fair: return "😐"
        case .good: return "😊"
        case .excellent: return "🌟"
        }
    }
    
    var color: Color {
        switch self {
        case .poor: return .red
        case .fair: return .orange
        case .good: return .green
        case .excellent: return Color(red: 0.4, green: 0.8, blue: 1.0)
        }
    }
}

enum SleepMood: String, Codable, CaseIterable {
    case energized = "energized"
    case refreshed = "refreshed"
    case neutral = "neutral"
    case tired = "tired"
    case exhausted = "exhausted"
    
    var emoji: String {
        switch self {
        case .energized: return "⚡️"
        case .refreshed: return "🌅"
        case .neutral: return "😐"
        case .tired: return "😪"
        case .exhausted: return "😫"
        }
    }
    
    var label: String {
        rawValue.capitalized
    }
}

// MARK: - Sleep Stats
struct SleepStats {
    let averageDuration: Double
    let averageQuality: Double
    let bestNight: SleepEntry?
    let worstNight: SleepEntry?
    let totalEntries: Int
    let weeklyTrend: [DailySleepStat]
    
    var averageDurationFormatted: String {
        let hours = Int(averageDuration)
        let minutes = Int((averageDuration - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }
    
    var sleepScore: Int {
        // Calculate sleep score based on duration and quality
        let durationScore = min(averageDuration / 8.0, 1.0) * 50 // Max 50 points for 8+ hours
        let qualityScore = (averageQuality / 4.0) * 50 // Max 50 points for excellent quality
        return Int(durationScore + qualityScore)
    }
}

struct DailySleepStat: Identifiable {
    let id = UUID()
    let date: Date
    let duration: Double
    let quality: Double
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Sleep Manager
class SleepManager: ObservableObject {
    static let shared = SleepManager()
    
    @Published var sleepEntries: [SleepEntry] = []
    @Published var todayEntry: SleepEntry?
    @Published var weeklyStats: SleepStats?
    @Published var sleepGoal: Double = 8.0 // Default 8 hours
    @Published var bedtimeReminder: Date?
    @Published var isLoading = false
    
    private let userDefaults = UserDefaults.standard
    private let entriesKey = "sleepEntries"
    private let goalKey = "sleepGoal"
    private let reminderKey = "bedtimeReminder"
    private let healthStore = HKHealthStore()
    
    private init() {
        loadData()
        calculateWeeklyStats()
    }
    
    // MARK: - Data Persistence
    private func loadData() {
        if let data = userDefaults.data(forKey: entriesKey),
           let entries = try? JSONDecoder().decode([SleepEntry].self, from: data) {
            sleepEntries = entries.sorted { $0.createdAt > $1.createdAt }
        }
        
        sleepGoal = userDefaults.double(forKey: goalKey)
        if sleepGoal == 0 { sleepGoal = 8.0 }
        
        if let reminderData = userDefaults.object(forKey: reminderKey) as? Date {
            bedtimeReminder = reminderData
        }
        
        // Find today's entry
        todayEntry = sleepEntries.first { Calendar.current.isDateInToday($0.createdAt) }
    }
    
    private func saveData() {
        if let data = try? JSONEncoder().encode(sleepEntries) {
            userDefaults.set(data, forKey: entriesKey)
        }
        userDefaults.set(sleepGoal, forKey: goalKey)
        if let reminder = bedtimeReminder {
            userDefaults.set(reminder, forKey: reminderKey)
        }
    }
    
    // MARK: - Sleep Entry Management
    func logSleep(bedtime: Date, wakeTime: Date, quality: SleepQuality, notes: String? = nil, mood: SleepMood? = nil) {
        let entry = SleepEntry(bedtime: bedtime, wakeTime: wakeTime, quality: quality, notes: notes, mood: mood)
        
        // Remove existing entry for today if exists
        sleepEntries.removeAll { Calendar.current.isDateInToday($0.createdAt) }
        
        sleepEntries.insert(entry, at: 0)
        todayEntry = entry
        saveData()
        calculateWeeklyStats()
        
        // Award points for logging sleep
        Task { @MainActor in
            StreakManager.shared.awardPoints(15)
        }
        
        // Sync to HealthKit if authorized
        Task {
            await syncToHealthKit(entry: entry)
        }
    }
    
    func updateEntry(_ entry: SleepEntry) {
        if let index = sleepEntries.firstIndex(where: { $0.id == entry.id }) {
            sleepEntries[index] = entry
            if Calendar.current.isDateInToday(entry.createdAt) {
                todayEntry = entry
            }
            saveData()
            calculateWeeklyStats()
        }
    }
    
    func deleteEntry(_ entry: SleepEntry) {
        sleepEntries.removeAll { $0.id == entry.id }
        if todayEntry?.id == entry.id {
            todayEntry = nil
        }
        saveData()
        calculateWeeklyStats()
    }
    
    // MARK: - Stats Calculation
    func calculateWeeklyStats() {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        let weekEntries = sleepEntries.filter { $0.createdAt >= weekAgo }
        
        guard !weekEntries.isEmpty else {
            weeklyStats = SleepStats(
                averageDuration: 0,
                averageQuality: 0,
                bestNight: nil,
                worstNight: nil,
                totalEntries: 0,
                weeklyTrend: []
            )
            return
        }
        
        let totalDuration = weekEntries.reduce(0.0) { $0 + $1.durationHours }
        let totalQuality = weekEntries.reduce(0.0) { $0 + Double($1.quality.rawValue) }
        
        let avgDuration = totalDuration / Double(weekEntries.count)
        let avgQuality = totalQuality / Double(weekEntries.count)
        
        let best = weekEntries.max { $0.durationHours < $1.durationHours }
        let worst = weekEntries.min { $0.durationHours < $1.durationHours }
        
        // Build weekly trend
        var trend: [DailySleepStat] = []
        for dayOffset in (0..<7).reversed() {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            let dayEntry = weekEntries.first { calendar.isDate($0.createdAt, inSameDayAs: date) }
            
            trend.append(DailySleepStat(
                date: date,
                duration: dayEntry?.durationHours ?? 0,
                quality: Double(dayEntry?.quality.rawValue ?? 0)
            ))
        }
        
        weeklyStats = SleepStats(
            averageDuration: avgDuration,
            averageQuality: avgQuality,
            bestNight: best,
            worstNight: worst,
            totalEntries: weekEntries.count,
            weeklyTrend: trend
        )
    }
    
    // MARK: - Sleep Goal
    func setSleepGoal(_ hours: Double) {
        sleepGoal = hours
        saveData()
    }
    
    var goalProgress: Double {
        guard let today = todayEntry else { return 0 }
        return min(today.durationHours / sleepGoal, 1.0)
    }
    
    // MARK: - HealthKit Integration
    func requestHealthKitAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        try await healthStore.requestAuthorization(toShare: [sleepType], read: [sleepType])
    }
    
    func syncToHealthKit(entry: SleepEntry) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        let sample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: entry.bedtime,
            end: entry.wakeTime
        )
        
        do {
            try await healthStore.save(sample)
            print("✅ Sleep data synced to HealthKit")
        } catch {
            print("❌ Failed to sync sleep to HealthKit: \(error)")
        }
    }
    
    func fetchFromHealthKit() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        
        do {
            let results = try await descriptor.result(for: healthStore)
            if let sample = results.first {
                await MainActor.run {
                    // Only update if we don't have an entry for today
                    if todayEntry == nil {
                        let entry = SleepEntry(
                            bedtime: sample.startDate,
                            wakeTime: sample.endDate,
                            quality: .good // Default quality from HealthKit
                        )
                        sleepEntries.insert(entry, at: 0)
                        todayEntry = entry
                        saveData()
                        calculateWeeklyStats()
                    }
                }
            }
        } catch {
            print("❌ Failed to fetch sleep from HealthKit: \(error)")
        }
    }
    
    // MARK: - Sleep Tips
    static let sleepTips: [String] = [
        "Keep a consistent sleep schedule, even on weekends",
        "Create a relaxing bedtime routine",
        "Make your bedroom dark, quiet, and cool",
        "Avoid screens 1 hour before bed",
        "Limit caffeine after 2 PM",
        "Exercise regularly, but not too close to bedtime",
        "Avoid large meals before sleep",
        "Try relaxation techniques like deep breathing",
        "Keep naps short (20-30 minutes)",
        "Get exposure to natural light during the day"
    ]
    
    var randomTip: String {
        SleepManager.sleepTips.randomElement() ?? SleepManager.sleepTips[0]
    }
}
