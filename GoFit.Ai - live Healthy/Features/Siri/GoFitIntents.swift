import AppIntents
import Foundation

// MARK: - Log Water Intent
/// "Hey Siri, log water in GoFit" or "Hey Siri, I drank a glass of water"
/// Logs water intake directly into the app without opening it.
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water"
    static var description = IntentDescription("Log water or liquid intake in GoFit")
    
    // Siri will ask "How much water?" if not provided in the phrase
    @Parameter(title: "Amount", description: "Amount of water in ml (e.g. 250 for a glass)")
    var amountML: Int?
    
    @Parameter(title: "Drink Type", description: "Type of drink")
    var drinkType: DrinkTypeEntity?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amountML) ml of \(\.$drinkType)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ml = amountML ?? 250 // Default: 1 glass = 250ml
        let liters = Double(ml) / 1000.0
        let type = drinkType?.name ?? "water"
        
        if type.lowercased() == "water" {
            WaterIntakeManager.shared.logWater(liters)
        } else {
            // Log as beverage with estimated calories
            let calories = estimateCalories(for: type, ml: ml)
            WaterIntakeManager.shared.logBeverage(name: type, liters: liters, calories: calories)
        }
        
        // Also reward the user
        RewardEngine.shared.rewardMealLog()
        
        let total = WaterIntakeManager.shared.todayWaterIntake
        let goal = WaterIntakeManager.shared.waterGoal
        let remaining = max(0, goal - total)
        
        let emoji = type.lowercased() == "water" ? "💧" : "🥤"
        
        if remaining <= 0 {
            return .result(dialog: "\(emoji) Logged \(ml)ml of \(type)! You've hit your daily goal of \(String(format: "%.1f", goal))L — great job! 🎉")
        } else {
            return .result(dialog: "\(emoji) Logged \(ml)ml of \(type). Total today: \(String(format: "%.1f", total))L. \(String(format: "%.1f", remaining))L to go!")
        }
    }
    
    private func estimateCalories(for drink: String, ml: Int) -> Double {
        let name = drink.lowercased()
        let multiplier = Double(ml) / 250.0 // per 250ml serving
        
        if name.contains("juice") || name.contains("orange") || name.contains("apple") {
            return 110 * multiplier
        } else if name.contains("coffee") || name.contains("espresso") {
            return 5 * multiplier
        } else if name.contains("latte") {
            return 120 * multiplier
        } else if name.contains("milk") {
            return 100 * multiplier
        } else if name.contains("tea") {
            return 2 * multiplier
        } else if name.contains("soda") || name.contains("cola") || name.contains("coke") {
            return 140 * multiplier
        } else if name.contains("smoothie") || name.contains("shake") {
            return 200 * multiplier
        } else if name.contains("beer") {
            return 150 * multiplier
        } else if name.contains("wine") {
            return 125 * multiplier
        } else if name.contains("energy") {
            return 110 * multiplier
        } else if name.contains("coconut") {
            return 45 * multiplier
        }
        return 0 // Plain water or unknown
    }
}

// MARK: - Log Meal Intent
/// "Hey Siri, log a meal in GoFit" or "Hey Siri, I had a banana"
struct LogQuickMealIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Meal"
    static var description = IntentDescription("Quickly log a food item in GoFit")
    
    @Parameter(title: "Food Name", description: "What did you eat? (e.g. banana, rice, chicken)")
    var foodName: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$foodName)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let name = foodName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            return .result(dialog: "Please tell me what you ate!")
        }
        
        // Try local nutrition database first (FREE, no API)
        let nutrition = LocalNutritionDatabase.shared.nutritionForServing(name)
        
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        
        if let n = nutrition {
            calories = Double(n.calories)
            protein = n.protein
            carbs = n.carbs
            fat = n.fat
        } else {
            // Rough estimate for unknown foods
            calories = 150
            protein = 5
            carbs = 20
            fat = 5
        }
        
        // Log as a meal
        let mealItem = MealItem(
            name: name.capitalized,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            sugar: 0,
            portionSize: nil,
            quantity: "1 serving"
        )
        
        let loggedMeal = LoggedMeal(
            timestamp: Date(),
            mealType: .snack,
            items: [mealItem],
            totalCalories: calories,
            totalProtein: protein,
            totalCarbs: carbs,
            totalFat: fat,
            totalSugar: 0
        )
        
        LocalDailyLogStore.shared.addMeal(loggedMeal)
        
        // Also save to LocalMealCache for sync
        let cachedMeal = CachedMeal(
            id: UUID().uuidString,
            timestamp: Date(),
            items: [CachedMeal.CachedMealItem(
                name: name.capitalized,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                sugar: 0,
                portionSize: nil
            )],
            totalCalories: calories,
            totalProtein: protein,
            totalCarbs: carbs,
            totalFat: fat,
            totalSugar: 0,
            mealType: "snack",
            synced: false
        )
        LocalMealCache.shared.addMeal(cachedMeal)
        
        // Reward
        RewardEngine.shared.rewardMealLog()
        
        // Post notification to refresh UI
        NotificationCenter.default.post(name: NSNotification.Name("MealSaved"), object: nil)
        
        let source = nutrition != nil ? "" : " (estimated)"
        return .result(dialog: "🍽️ Logged \(name.capitalized)\(source): \(Int(calories)) cal, \(String(format: "%.0f", protein))g protein. Keep it up! 💪")
    }
}

// MARK: - Check Progress Intent
/// "Hey Siri, how's my GoFit progress?" or "Hey Siri, GoFit status"
struct CheckProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Check My Progress"
    static var description = IntentDescription("Check your daily fitness progress in GoFit")
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let water = WaterIntakeManager.shared
        let log = LocalDailyLogStore.shared.getTodayLog()
        
        let waterStr = String(format: "%.1f", water.todayWaterIntake)
        let goalStr = String(format: "%.1f", water.waterGoal)
        let mealCount = log.meals.count
        let totalCal = log.meals.reduce(0.0) { $0 + $1.totalCalories }
        
        var summary = "📊 Today's GoFit Progress:\n"
        summary += "💧 Water: \(waterStr)L / \(goalStr)L"
        if water.isGoalMet { summary += " ✅" }
        summary += "\n🍽️ Meals: \(mealCount) logged (\(Int(totalCal)) cal)"
        
        if let steps = log.steps, steps > 0 {
            summary += "\n👟 Steps: \(Int(steps))"
        }
        
        return .result(dialog: "\(summary)")
    }
}

// MARK: - Drink Type Entity
/// Custom entity so Siri understands drink types
struct DrinkTypeEntity: AppEntity {
    var id: String
    var name: String
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Drink Type")
    static var defaultQuery = DrinkTypeQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    static let allDrinks: [DrinkTypeEntity] = [
        .init(id: "water", name: "Water"),
        .init(id: "coffee", name: "Coffee"),
        .init(id: "tea", name: "Tea"),
        .init(id: "juice", name: "Juice"),
        .init(id: "milk", name: "Milk"),
        .init(id: "smoothie", name: "Smoothie"),
        .init(id: "soda", name: "Soda"),
        .init(id: "latte", name: "Latte"),
        .init(id: "coconut_water", name: "Coconut Water"),
        .init(id: "energy_drink", name: "Energy Drink"),
    ]
}

struct DrinkTypeQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [DrinkTypeEntity] {
        DrinkTypeEntity.allDrinks.filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [DrinkTypeEntity] {
        DrinkTypeEntity.allDrinks
    }
}
