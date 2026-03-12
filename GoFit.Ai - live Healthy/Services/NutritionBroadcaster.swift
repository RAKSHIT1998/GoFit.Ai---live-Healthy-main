import Foundation
import Combine

/// Central broadcaster for nutrition data changes across the entire app.
/// When food/liquid is logged ANYWHERE, ALL views update instantly via on-device storage.
/// Subscribe to `@ObservedObject var nutrition = NutritionBroadcaster.shared` in any view.
final class NutritionBroadcaster: ObservableObject {
    static let shared = NutritionBroadcaster()
    
    // MARK: - Published Live Data (always up-to-date)
    @Published var todayCalories: Double = 0
    @Published var todayProtein: Double = 0
    @Published var todayCarbs: Double = 0
    @Published var todayFat: Double = 0
    @Published var todaySugar: Double = 0
    @Published var todayWater: Double = 0
    @Published var todayMealsCount: Int = 0
    @Published var todaySteps: Int = 0
    @Published var todayCaloriesBurned: Double = 0
    @Published var lastUpdateTime: Date = Date()
    
    // Notification names for cross-app updates
    static let nutritionDidUpdate = Notification.Name("GoFitNutritionDidUpdate")
    static let mealDidLog = Notification.Name("GoFitMealDidLog")
    static let liquidDidLog = Notification.Name("GoFitLiquidDidLog")
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        refreshFromLocalStorage()
        observeChanges()
    }
    
    // MARK: - Refresh from Local Storage
    
    func refreshFromLocalStorage() {
        let dailyLog = LocalDailyLogStore.shared.getTodayLog()
        let mealCache = LocalMealCache.shared.getTodayTotals()
        
        // Use the best available data (whichever has more)
        let logCalories = dailyLog.totalCalories
        let cacheCalories = mealCache.calories
        
        todayCalories = max(logCalories, cacheCalories)
        todayProtein = max(dailyLog.totalProtein, mealCache.protein)
        todayCarbs = max(dailyLog.totalCarbs, mealCache.carbs)
        todayFat = max(dailyLog.totalFat, mealCache.fat)
        todaySugar = max(dailyLog.totalSugar, mealCache.sugar)
        todayWater = dailyLog.totalLiquid
        todayMealsCount = max(dailyLog.meals.count, LocalMealCache.shared.getTodayMeals().count)
        todaySteps = dailyLog.steps ?? 0
        todayCaloriesBurned = dailyLog.caloriesBurned
        lastUpdateTime = Date()
        
        // Post notification for any listeners (non-Combine views)
        NotificationCenter.default.post(name: Self.nutritionDidUpdate, object: nil, userInfo: [
            "calories": todayCalories,
            "protein": todayProtein,
            "carbs": todayCarbs,
            "fat": todayFat,
            "water": todayWater,
            "meals": todayMealsCount
        ])
    }
    
    // MARK: - Observe Changes
    
    private func observeChanges() {
        // Observe LocalDailyLogStore changes
        LocalDailyLogStore.shared.$logs
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFromLocalStorage()
            }
            .store(in: &cancellables)
        
        // Observe external meal/liquid log notifications
        NotificationCenter.default.publisher(for: Self.mealDidLog)
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFromLocalStorage()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: Self.liquidDidLog)
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshFromLocalStorage()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Formatted Values for Sharing
    
    /// Formatted summary string for sharing in chat
    var formattedSummary: String {
        return """
        📊 My GoFit.Ai Progress Today:
        🔥 \(Int(todayCalories)) kcal consumed
        💪 P: \(Int(todayProtein))g | C: \(Int(todayCarbs))g | F: \(Int(todayFat))g
        💧 Water: \(String(format: "%.1f", todayWater))L
        🍽️ \(todayMealsCount) meals logged
        🚶 \(todaySteps) steps
        ⚡️ \(Int(todayCaloriesBurned)) kcal burned
        """
    }
    
    /// Shareable card data for animated rendering
    var animatedShareData: ShareableNutritionCard {
        ShareableNutritionCard(
            calories: Int(todayCalories),
            protein: Int(todayProtein),
            carbs: Int(todayCarbs),
            fat: Int(todayFat),
            water: todayWater,
            meals: todayMealsCount,
            steps: todaySteps,
            caloriesBurned: Int(todayCaloriesBurned)
        )
    }
}

// MARK: - Shareable Data Card
struct ShareableNutritionCard {
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let water: Double
    let meals: Int
    let steps: Int
    let caloriesBurned: Int
    
    var isPopulated: Bool {
        calories > 0 || protein > 0 || meals > 0 || water > 0
    }
}
