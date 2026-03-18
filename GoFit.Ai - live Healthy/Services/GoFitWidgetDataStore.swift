import Foundation
import WidgetKit

// MARK: - Widget Data Store
/// Shared data bridge between the main app and the Widget extension.
/// Writes to UserDefaults so the widget can read it.

final class GoFitWidgetDataStore {
    static let shared = GoFitWidgetDataStore()
    
    private let defaults = UserDefaults.standard
    private let prefix = "widget_"
    
    private init() {}
    
    // MARK: - Write (called from main app)
    
    /// Call this whenever relevant data changes to keep widget fresh
    @MainActor
    func refresh() {
        let water = WaterIntakeManager.shared
        let log = LocalDailyLogStore.shared.getTodayLog()
        
        defaults.set(water.todayWaterIntake, forKey: k("waterLiters"))
        defaults.set(water.waterGoal, forKey: k("waterGoal"))
        defaults.set(log.meals.count, forKey: k("mealCount"))
        defaults.set(log.totalCalories, forKey: k("calories"))
        defaults.set(log.totalProtein, forKey: k("protein"))
        defaults.set(log.totalCarbs, forKey: k("carbs"))
        defaults.set(log.totalFat, forKey: k("fat"))
        defaults.set(log.steps ?? 0, forKey: k("steps"))
        defaults.set(Date().timeIntervalSince1970, forKey: k("lastUpdate"))
        
        // Trigger widget reload
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // MARK: - Read (called from widget)
    
    var waterLiters: Double { defaults.double(forKey: k("waterLiters")) }
    var waterGoal: Double {
        let g = defaults.double(forKey: k("waterGoal"))
        return g > 0 ? g : 2.0 // default 2L
    }
    var waterProgress: Double { min(waterLiters / waterGoal, 1.0) }
    var mealCount: Int { defaults.integer(forKey: k("mealCount")) }
    var calories: Double { defaults.double(forKey: k("calories")) }
    var protein: Double { defaults.double(forKey: k("protein")) }
    var carbs: Double { defaults.double(forKey: k("carbs")) }
    var fat: Double { defaults.double(forKey: k("fat")) }
    var steps: Int { defaults.integer(forKey: k("steps")) }
    var lastUpdate: Date { Date(timeIntervalSince1970: defaults.double(forKey: k("lastUpdate"))) }
    
    private func k(_ key: String) -> String { "\(prefix)\(key)" }
}
