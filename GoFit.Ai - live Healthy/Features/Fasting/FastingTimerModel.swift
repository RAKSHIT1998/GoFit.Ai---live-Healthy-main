import Foundation
import SwiftUI

/// Persistent fasting timer model — state survives app close / sheet dismiss
class FastingTimerModel: ObservableObject {
    static let shared = FastingTimerModel()
    
    // MARK: - Published State
    @Published var isFasting: Bool = false
    @Published var fastingStart: Date? = nil
    @Published var fastingWindowHours: Int = 16
    @Published var timeRemaining: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var streak: Int = 0
    @Published var completedFasts: Int = 0
    @Published var totalFastingHours: Double = 0
    @Published var lastCompletedDate: Date? = nil
    
    // History
    @Published var fastingHistory: [FastingRecord] = []
    
    private let defaults = UserDefaults.standard
    private let isFastingKey = "fasting_isFasting"
    private let startKey = "fasting_startDate"
    private let windowKey = "fasting_windowHours"
    private let streakKey = "fasting_streak"
    private let completedKey = "fasting_completedCount"
    private let totalHoursKey = "fasting_totalHours"
    private let lastCompletedKey = "fasting_lastCompleted"
    private let historyKey = "fasting_history"
    
    private init() {
        loadState()
        // If we were fasting, update timer
        if isFasting, let start = fastingStart {
            let elapsed = Date().timeIntervalSince(start)
            let total = TimeInterval(fastingWindowHours * 3600)
            if elapsed >= total {
                // Fast completed while app was closed
                completeFast()
            } else {
                timeRemaining = total - elapsed
                progress = min(1.0, elapsed / total)
            }
        }
    }
    
    // MARK: - Actions
    
    func startFast(hours: Int? = nil) {
        if let hours = hours {
            fastingWindowHours = hours
        }
        fastingStart = Date()
        isFasting = true
        timeRemaining = TimeInterval(fastingWindowHours * 3600)
        progress = 0
        saveState()
        
        HapticManager.shared.success()
    }
    
    func endFast() {
        // Record partial fast
        if let start = fastingStart {
            let elapsed = Date().timeIntervalSince(start)
            let record = FastingRecord(
                startDate: start,
                endDate: Date(),
                targetHours: fastingWindowHours,
                actualHours: elapsed / 3600,
                completed: false
            )
            fastingHistory.insert(record, at: 0)
            if fastingHistory.count > 30 { fastingHistory = Array(fastingHistory.prefix(30)) }
        }
        
        fastingStart = nil
        isFasting = false
        timeRemaining = 0
        progress = 0
        saveState()
        
        HapticManager.shared.warning()
    }
    
    func completeFast() {
        guard let start = fastingStart else { return }
        
        let elapsed = Date().timeIntervalSince(start)
        let record = FastingRecord(
            startDate: start,
            endDate: Date(),
            targetHours: fastingWindowHours,
            actualHours: elapsed / 3600,
            completed: true
        )
        fastingHistory.insert(record, at: 0)
        if fastingHistory.count > 30 { fastingHistory = Array(fastingHistory.prefix(30)) }
        
        completedFasts += 1
        totalFastingHours += elapsed / 3600
        
        // Update streak
        let calendar = Calendar.current
        if let last = lastCompletedDate, calendar.isDateInYesterday(last) || calendar.isDateInToday(last) {
            streak += 1
        } else if lastCompletedDate == nil || !calendar.isDateInToday(lastCompletedDate!) {
            streak = 1
        }
        lastCompletedDate = Date()
        
        fastingStart = nil
        isFasting = false
        timeRemaining = 0
        progress = 1.0
        saveState()
        
        // Award streak points
        Task { @MainActor in
            StreakManager.shared.awardPoints(20)
        }
        HapticManager.shared.success()
    }
    
    func updateTimer() {
        guard isFasting, let start = fastingStart else { return }
        let elapsed = Date().timeIntervalSince(start)
        let total = TimeInterval(fastingWindowHours * 3600)
        timeRemaining = max(0, total - elapsed)
        
        if total > 0 {
            progress = min(1.0, elapsed / total)
        } else {
            progress = 0
        }
        
        if timeRemaining <= 0 {
            completeFast()
        }
    }
    
    // MARK: - Helpers
    
    var elapsedString: String {
        guard let start = fastingStart else { return "0h 0m" }
        let elapsed = Date().timeIntervalSince(start)
        let h = Int(elapsed) / 3600
        let m = (Int(elapsed) % 3600) / 60
        return "\(h)h \(m)m"
    }
    
    var remainingString: String {
        let h = Int(timeRemaining) / 3600
        let m = (Int(timeRemaining) % 3600) / 60
        let s = Int(timeRemaining) % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
    
    var statusText: String {
        if isFasting {
            return "Fasting (\(fastingWindowHours):\(24 - fastingWindowHours))"
        }
        return "Not fasting"
    }
    
    // MARK: - Persistence
    
    private func saveState() {
        defaults.set(isFasting, forKey: isFastingKey)
        defaults.set(fastingStart, forKey: startKey)
        defaults.set(fastingWindowHours, forKey: windowKey)
        defaults.set(streak, forKey: streakKey)
        defaults.set(completedFasts, forKey: completedKey)
        defaults.set(totalFastingHours, forKey: totalHoursKey)
        defaults.set(lastCompletedDate, forKey: lastCompletedKey)
        
        if let data = try? JSONEncoder().encode(fastingHistory) {
            defaults.set(data, forKey: historyKey)
        }
    }
    
    private func loadState() {
        isFasting = defaults.bool(forKey: isFastingKey)
        fastingStart = defaults.object(forKey: startKey) as? Date
        
        let savedWindow = defaults.integer(forKey: windowKey)
        fastingWindowHours = savedWindow > 0 ? savedWindow : 16
        
        streak = defaults.integer(forKey: streakKey)
        completedFasts = defaults.integer(forKey: completedKey)
        totalFastingHours = defaults.double(forKey: totalHoursKey)
        lastCompletedDate = defaults.object(forKey: lastCompletedKey) as? Date
        
        // Check streak validity
        if let last = lastCompletedDate {
            let calendar = Calendar.current
            if !calendar.isDateInToday(last) && !calendar.isDateInYesterday(last) {
                streak = 0 // Reset if more than 1 day gap
            }
        }
        
        if let data = defaults.data(forKey: historyKey),
           let history = try? JSONDecoder().decode([FastingRecord].self, from: data) {
            fastingHistory = history
        }
    }
}

// MARK: - Fasting Record
struct FastingRecord: Codable, Identifiable {
    let id: String
    let startDate: Date
    let endDate: Date
    let targetHours: Int
    let actualHours: Double
    let completed: Bool
    
    init(id: String = UUID().uuidString, startDate: Date, endDate: Date, targetHours: Int, actualHours: Double, completed: Bool) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.targetHours = targetHours
        self.actualHours = actualHours
        self.completed = completed
    }
    
    var actualHoursFormatted: String {
        let h = Int(actualHours)
        let m = Int((actualHours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }
}
