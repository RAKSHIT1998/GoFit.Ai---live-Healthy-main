import AppIntents
import Foundation

// MARK: - Log Water / Drink Intent
/// "Hey Siri, log water in GoFit"
/// "Hey Siri, I had 30ml whiskey with GoFit"
/// "Hey Siri, I drank 180ml vodka with GoFit"
/// Logs any liquid — water, coffee, alcohol, etc — without opening the app.
struct LogWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Water or Drink"
    static var description = IntentDescription("Log water, beverages, or alcohol intake in GoFit")
    
    @Parameter(title: "Amount (ml)", description: "Amount in ml (e.g. 30 for a shot, 250 for a glass, 500 for a bottle)")
    var amountML: Int?
    
    @Parameter(title: "Drink Type", description: "Type of drink (water, whiskey, vodka, beer, etc.)")
    var drinkType: DrinkTypeEntity?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amountML) ml of \(\.$drinkType)")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let type = drinkType?.name ?? "water"
        let typeLower = type.lowercased()
        
        // Smart default amounts based on drink type
        let ml: Int
        if let provided = amountML {
            ml = provided
        } else {
            ml = Self.defaultML(for: typeLower)
        }
        
        let liters = Double(ml) / 1000.0
        let calories = Self.estimateCalories(for: typeLower, ml: ml)
        let isAlcohol = Self.isAlcoholicDrink(typeLower)
        let abv = Self.estimateABV(for: typeLower)
        
        if typeLower == "water" {
            WaterIntakeManager.shared.logWater(liters)
        } else {
            WaterIntakeManager.shared.logBeverage(name: type, liters: liters, calories: calories)
        }
        
        // Reward XP
        RewardEngine.shared.rewardMealLog()
        
        // Refresh widget data
        GoFitWidgetDataStore.shared.refresh()
        
        let total = WaterIntakeManager.shared.todayWaterIntake
        let goal = WaterIntakeManager.shared.waterGoal
        let remaining = max(0, goal - total)
        
        // Build a fun response
        var response = ""
        if isAlcohol {
            let standardDrinks = Self.standardDrinks(ml: ml, abv: abv)
            let emoji = Self.alcoholEmoji(for: typeLower)
            response = "\(emoji) Logged \(ml)ml \(type) (~\(Int(calories)) cal, \(String(format: "%.1f", standardDrinks)) std drinks)."
            if standardDrinks >= 3 {
                response += " Take it easy tonight! 😅"
            } else if standardDrinks >= 2 {
                response += " Enjoy responsibly! 🥂"
            } else {
                response += " Cheers! 🥂"
            }
        } else {
            let emoji = typeLower == "water" ? "💧" : "🥤"
            response = "\(emoji) Logged \(ml)ml of \(type) (~\(Int(calories)) cal)."
        }
        
        if remaining <= 0 {
            response += " Daily liquid goal hit! 🎉"
        } else {
            response += " Total: \(String(format: "%.1f", total))L / \(String(format: "%.1f", goal))L"
        }
        
        return .result(dialog: "\(response)")
    }
    
    // MARK: - Smart Defaults
    
    /// Default ml when user doesn't specify an amount
    static func defaultML(for drink: String) -> Int {
        if drink.contains("shot") || drink.contains("whiskey") || drink.contains("whisky")
            || drink.contains("vodka") || drink.contains("rum") || drink.contains("gin")
            || drink.contains("tequila") || drink.contains("brandy") || drink.contains("cognac")
            || drink.contains("mezcal") || drink.contains("absinthe") || drink.contains("schnapps") {
            return 30 // standard shot
        } else if drink.contains("wine") || drink.contains("champagne") || drink.contains("prosecco") {
            return 150 // standard wine pour
        } else if drink.contains("beer") || drink.contains("ale") || drink.contains("lager")
                    || drink.contains("stout") || drink.contains("cider") {
            return 330 // standard can/bottle
        } else if drink.contains("cocktail") || drink.contains("margarita") || drink.contains("mojito")
                    || drink.contains("martini") || drink.contains("negroni") || drink.contains("daiquiri") {
            return 200 // cocktail glass
        } else if drink.contains("espresso") {
            return 30
        } else if drink.contains("coffee") || drink.contains("latte") || drink.contains("cappuccino") {
            return 250
        } else if drink.contains("tea") {
            return 250
        } else {
            return 250 // default glass
        }
    }
    
    // MARK: - Calorie Estimation
    
    static func estimateCalories(for drink: String, ml: Int) -> Double {
        let d = Double(ml)
        
        // --- Spirits (pure, ~220-250 cal per 100ml) ---
        if drink.contains("whiskey") || drink.contains("whisky") || drink.contains("bourbon") {
            return d * 2.5 // ~250 cal/100ml (40% ABV)
        } else if drink.contains("vodka") {
            return d * 2.3 // ~230 cal/100ml (40% ABV)
        } else if drink.contains("rum") {
            return d * 2.3
        } else if drink.contains("gin") {
            return d * 2.6
        } else if drink.contains("tequila") {
            return d * 2.3
        } else if drink.contains("brandy") || drink.contains("cognac") {
            return d * 2.4
        } else if drink.contains("mezcal") || drink.contains("absinthe") {
            return d * 2.8 // higher ABV
        } else if drink.contains("schnapps") || drink.contains("liqueur") {
            return d * 3.0 // sugar-heavy
        }
        // --- Cocktails ---
        else if drink.contains("cocktail") || drink.contains("margarita") || drink.contains("mojito")
                    || drink.contains("martini") || drink.contains("daiquiri") || drink.contains("negroni") {
            return d * 1.5 // ~150 cal/100ml (mixed)
        }
        // --- Wine ---
        else if drink.contains("wine") {
            return d * 0.85 // ~85 cal/100ml
        } else if drink.contains("champagne") || drink.contains("prosecco") {
            return d * 0.78
        }
        // --- Beer ---
        else if drink.contains("beer") || drink.contains("ale") || drink.contains("lager")
                    || drink.contains("stout") {
            return d * 0.43 // ~43 cal/100ml
        } else if drink.contains("cider") {
            return d * 0.50
        }
        // --- Non-Alcoholic ---
        else if drink.contains("juice") || drink.contains("orange") || drink.contains("apple") {
            return d * 0.44
        } else if drink.contains("coffee") || drink.contains("espresso") {
            return d * 0.02
        } else if drink.contains("latte") || drink.contains("cappuccino") {
            return d * 0.48
        } else if drink.contains("milk") {
            return d * 0.40
        } else if drink.contains("tea") {
            return d * 0.01
        } else if drink.contains("soda") || drink.contains("cola") || drink.contains("coke") {
            return d * 0.42
        } else if drink.contains("smoothie") || drink.contains("shake") {
            return d * 0.60
        } else if drink.contains("energy") {
            return d * 0.45
        } else if drink.contains("coconut") {
            return d * 0.19
        }
        return 0 // Plain water
    }
    
    // MARK: - Alcohol Helpers
    
    static func isAlcoholicDrink(_ drink: String) -> Bool {
        let alcoholKeywords = [
            "whiskey", "whisky", "bourbon", "scotch",
            "vodka", "rum", "gin", "tequila", "mezcal",
            "brandy", "cognac", "absinthe", "schnapps", "liqueur",
            "beer", "ale", "lager", "stout", "cider",
            "wine", "champagne", "prosecco",
            "cocktail", "margarita", "mojito", "martini", "negroni", "daiquiri",
            "sake", "soju"
        ]
        return alcoholKeywords.contains { drink.contains($0) }
    }
    
    static func estimateABV(for drink: String) -> Double {
        if drink.contains("absinthe") { return 0.60 }
        if drink.contains("mezcal") { return 0.45 }
        if drink.contains("whiskey") || drink.contains("whisky") || drink.contains("bourbon")
            || drink.contains("scotch") || drink.contains("vodka") || drink.contains("rum")
            || drink.contains("gin") || drink.contains("tequila") || drink.contains("brandy")
            || drink.contains("cognac") { return 0.40 }
        if drink.contains("schnapps") || drink.contains("liqueur") { return 0.25 }
        if drink.contains("wine") || drink.contains("champagne") || drink.contains("prosecco") { return 0.13 }
        if drink.contains("sake") || drink.contains("soju") { return 0.15 }
        if drink.contains("beer") || drink.contains("ale") || drink.contains("lager")
            || drink.contains("stout") { return 0.05 }
        if drink.contains("cider") { return 0.05 }
        if drink.contains("cocktail") || drink.contains("margarita") || drink.contains("mojito")
            || drink.contains("martini") || drink.contains("negroni") || drink.contains("daiquiri") { return 0.15 }
        return 0
    }
    
    /// Standard drinks (1 std = 14g pure alcohol)
    static func standardDrinks(ml: Int, abv: Double) -> Double {
        let pureAlcoholGrams = Double(ml) * abv * 0.789
        return pureAlcoholGrams / 14.0
    }
    
    static func alcoholEmoji(for drink: String) -> String {
        if drink.contains("whiskey") || drink.contains("whisky") || drink.contains("bourbon") || drink.contains("scotch") { return "🥃" }
        if drink.contains("vodka") || drink.contains("gin") || drink.contains("martini") { return "🍸" }
        if drink.contains("wine") || drink.contains("champagne") || drink.contains("prosecco") { return "🍷" }
        if drink.contains("beer") || drink.contains("ale") || drink.contains("lager") || drink.contains("stout") { return "🍺" }
        if drink.contains("cocktail") || drink.contains("margarita") || drink.contains("mojito") || drink.contains("daiquiri") { return "🍹" }
        if drink.contains("sake") { return "🍶" }
        return "🥃"
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
        
        // Refresh widget data
        GoFitWidgetDataStore.shared.refresh()
        
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
/// Custom entity so Siri understands drink types — including alcohol
struct DrinkTypeEntity: AppEntity {
    var id: String
    var name: String
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Drink Type")
    static var defaultQuery = DrinkTypeQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
    
    static let allDrinks: [DrinkTypeEntity] = [
        // Non-Alcoholic
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
        // Spirits
        .init(id: "whiskey", name: "Whiskey"),
        .init(id: "vodka", name: "Vodka"),
        .init(id: "rum", name: "Rum"),
        .init(id: "gin", name: "Gin"),
        .init(id: "tequila", name: "Tequila"),
        .init(id: "brandy", name: "Brandy"),
        // Wine & Beer
        .init(id: "wine", name: "Wine"),
        .init(id: "beer", name: "Beer"),
        .init(id: "champagne", name: "Champagne"),
        .init(id: "cider", name: "Cider"),
        // Cocktails
        .init(id: "cocktail", name: "Cocktail"),
        .init(id: "margarita", name: "Margarita"),
        .init(id: "mojito", name: "Mojito"),
        .init(id: "martini", name: "Martini"),
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
