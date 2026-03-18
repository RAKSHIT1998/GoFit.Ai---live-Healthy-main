import Foundation

// MARK: - Local Food Nutrition Database
/// Provides instant calorie/macro lookups for 150+ common foods WITHOUT any API call.
/// This completely bypasses OpenAI GPT-4o for everyday items like "apple", "rice", "chicken breast",
/// saving ~$0.02–$0.10 per avoided photo analysis call.
///
/// Usage:
///   if let match = LocalNutritionDatabase.shared.lookup("grilled chicken breast") {
///       // Use match directly — no API needed
///   } else {
///       // Fall through to AI photo analysis
///   }
final class LocalNutritionDatabase {
    static let shared = LocalNutritionDatabase()
    
    struct NutritionInfo {
        let name: String
        let caloriesPer100g: Double
        let proteinPer100g: Double
        let carbsPer100g: Double
        let fatPer100g: Double
        let typicalServingGrams: Double
        let category: String
    }
    
    // MARK: - Database (per 100g values)
    
    private let database: [String: NutritionInfo] = {
        var db = [String: NutritionInfo]()
        
        func add(_ keys: [String], _ name: String, cal: Double, p: Double, c: Double, f: Double, serving: Double, cat: String) {
            let info = NutritionInfo(name: name, caloriesPer100g: cal, proteinPer100g: p, carbsPer100g: c, fatPer100g: f, typicalServingGrams: serving, category: cat)
            for key in keys {
                db[key.lowercased()] = info
            }
        }
        
        // ── Fruits ──
        add(["apple", "apples"], "Apple", cal: 52, p: 0.3, c: 14, f: 0.2, serving: 182, cat: "Fruit")
        add(["banana", "bananas"], "Banana", cal: 89, p: 1.1, c: 23, f: 0.3, serving: 118, cat: "Fruit")
        add(["orange", "oranges"], "Orange", cal: 47, p: 0.9, c: 12, f: 0.1, serving: 131, cat: "Fruit")
        add(["strawberry", "strawberries"], "Strawberries", cal: 32, p: 0.7, c: 7.7, f: 0.3, serving: 152, cat: "Fruit")
        add(["blueberry", "blueberries"], "Blueberries", cal: 57, p: 0.7, c: 14, f: 0.3, serving: 148, cat: "Fruit")
        add(["grape", "grapes"], "Grapes", cal: 69, p: 0.7, c: 18, f: 0.2, serving: 151, cat: "Fruit")
        add(["watermelon"], "Watermelon", cal: 30, p: 0.6, c: 8, f: 0.2, serving: 286, cat: "Fruit")
        add(["mango", "mangoes"], "Mango", cal: 60, p: 0.8, c: 15, f: 0.4, serving: 165, cat: "Fruit")
        add(["pineapple"], "Pineapple", cal: 50, p: 0.5, c: 13, f: 0.1, serving: 165, cat: "Fruit")
        add(["avocado", "avocados"], "Avocado", cal: 160, p: 2, c: 9, f: 15, serving: 150, cat: "Fruit")
        add(["peach", "peaches"], "Peach", cal: 39, p: 0.9, c: 10, f: 0.3, serving: 150, cat: "Fruit")
        add(["pear", "pears"], "Pear", cal: 57, p: 0.4, c: 15, f: 0.1, serving: 178, cat: "Fruit")
        add(["kiwi", "kiwis"], "Kiwi", cal: 61, p: 1.1, c: 15, f: 0.5, serving: 76, cat: "Fruit")
        add(["cherry", "cherries"], "Cherries", cal: 50, p: 1, c: 12, f: 0.3, serving: 138, cat: "Fruit")
        
        // ── Vegetables ──
        add(["broccoli"], "Broccoli", cal: 34, p: 2.8, c: 7, f: 0.4, serving: 156, cat: "Vegetable")
        add(["spinach"], "Spinach", cal: 23, p: 2.9, c: 3.6, f: 0.4, serving: 180, cat: "Vegetable")
        add(["carrot", "carrots"], "Carrot", cal: 41, p: 0.9, c: 10, f: 0.2, serving: 128, cat: "Vegetable")
        add(["tomato", "tomatoes"], "Tomato", cal: 18, p: 0.9, c: 3.9, f: 0.2, serving: 123, cat: "Vegetable")
        add(["cucumber", "cucumbers"], "Cucumber", cal: 15, p: 0.7, c: 3.6, f: 0.1, serving: 301, cat: "Vegetable")
        add(["bell pepper", "capsicum"], "Bell Pepper", cal: 31, p: 1, c: 6, f: 0.3, serving: 119, cat: "Vegetable")
        add(["onion", "onions"], "Onion", cal: 40, p: 1.1, c: 9, f: 0.1, serving: 110, cat: "Vegetable")
        add(["potato", "potatoes"], "Potato", cal: 77, p: 2, c: 17, f: 0.1, serving: 213, cat: "Vegetable")
        add(["sweet potato", "sweet potatoes"], "Sweet Potato", cal: 86, p: 1.6, c: 20, f: 0.1, serving: 200, cat: "Vegetable")
        add(["corn"], "Corn", cal: 86, p: 3.3, c: 19, f: 1.2, serving: 90, cat: "Vegetable")
        add(["lettuce", "salad"], "Lettuce", cal: 15, p: 1.4, c: 2.9, f: 0.2, serving: 85, cat: "Vegetable")
        add(["kale"], "Kale", cal: 49, p: 4.3, c: 9, f: 0.9, serving: 67, cat: "Vegetable")
        add(["cauliflower"], "Cauliflower", cal: 25, p: 1.9, c: 5, f: 0.3, serving: 124, cat: "Vegetable")
        add(["zucchini"], "Zucchini", cal: 17, p: 1.2, c: 3.1, f: 0.3, serving: 196, cat: "Vegetable")
        add(["mushroom", "mushrooms"], "Mushrooms", cal: 22, p: 3.1, c: 3.3, f: 0.3, serving: 96, cat: "Vegetable")
        add(["green beans"], "Green Beans", cal: 31, p: 1.8, c: 7, f: 0.2, serving: 125, cat: "Vegetable")
        
        // ── Proteins ──
        add(["chicken breast", "grilled chicken", "chicken"], "Chicken Breast", cal: 165, p: 31, c: 0, f: 3.6, serving: 174, cat: "Protein")
        add(["chicken thigh"], "Chicken Thigh", cal: 209, p: 26, c: 0, f: 11, serving: 116, cat: "Protein")
        add(["salmon"], "Salmon", cal: 208, p: 20, c: 0, f: 13, serving: 170, cat: "Protein")
        add(["tuna"], "Tuna", cal: 130, p: 28, c: 0, f: 1.3, serving: 142, cat: "Protein")
        add(["shrimp", "prawns"], "Shrimp", cal: 99, p: 24, c: 0.2, f: 0.3, serving: 85, cat: "Protein")
        add(["beef", "steak", "beef steak"], "Beef Steak", cal: 271, p: 26, c: 0, f: 18, serving: 221, cat: "Protein")
        add(["ground beef", "minced beef"], "Ground Beef", cal: 254, p: 17, c: 0, f: 20, serving: 113, cat: "Protein")
        add(["pork chop", "pork"], "Pork Chop", cal: 231, p: 25, c: 0, f: 14, serving: 146, cat: "Protein")
        add(["turkey breast", "turkey"], "Turkey Breast", cal: 135, p: 30, c: 0, f: 1, serving: 170, cat: "Protein")
        add(["lamb"], "Lamb", cal: 294, p: 25, c: 0, f: 21, serving: 170, cat: "Protein")
        add(["tofu"], "Tofu", cal: 76, p: 8, c: 1.9, f: 4.8, serving: 126, cat: "Protein")
        add(["tempeh"], "Tempeh", cal: 192, p: 20, c: 8, f: 11, serving: 84, cat: "Protein")
        add(["egg", "eggs", "boiled egg", "fried egg", "scrambled eggs"], "Egg", cal: 155, p: 13, c: 1.1, f: 11, serving: 50, cat: "Protein")
        add(["egg white", "egg whites"], "Egg White", cal: 52, p: 11, c: 0.7, f: 0.2, serving: 66, cat: "Protein")
        
        // ── Grains & Carbs ──
        add(["white rice", "rice", "steamed rice"], "White Rice (cooked)", cal: 130, p: 2.7, c: 28, f: 0.3, serving: 186, cat: "Grain")
        add(["brown rice"], "Brown Rice (cooked)", cal: 123, p: 2.6, c: 26, f: 1, serving: 195, cat: "Grain")
        add(["pasta", "spaghetti", "noodles", "penne"], "Pasta (cooked)", cal: 131, p: 5, c: 25, f: 1.1, serving: 140, cat: "Grain")
        add(["bread", "white bread", "toast"], "White Bread", cal: 265, p: 9, c: 49, f: 3.2, serving: 30, cat: "Grain")
        add(["whole wheat bread", "brown bread"], "Whole Wheat Bread", cal: 247, p: 13, c: 41, f: 3.4, serving: 30, cat: "Grain")
        add(["oatmeal", "oats", "porridge"], "Oatmeal (cooked)", cal: 71, p: 2.5, c: 12, f: 1.5, serving: 234, cat: "Grain")
        add(["quinoa"], "Quinoa (cooked)", cal: 120, p: 4.4, c: 21, f: 1.9, serving: 185, cat: "Grain")
        add(["tortilla", "wrap"], "Flour Tortilla", cal: 312, p: 8, c: 52, f: 8, serving: 64, cat: "Grain")
        add(["bagel"], "Bagel", cal: 257, p: 10, c: 50, f: 1.6, serving: 105, cat: "Grain")
        add(["cereal", "cornflakes"], "Cereal", cal: 357, p: 7, c: 84, f: 0.4, serving: 30, cat: "Grain")
        add(["granola"], "Granola", cal: 471, p: 10, c: 64, f: 20, serving: 55, cat: "Grain")
        
        // ── Dairy ──
        add(["milk", "whole milk"], "Whole Milk", cal: 61, p: 3.2, c: 4.8, f: 3.3, serving: 244, cat: "Dairy")
        add(["skim milk", "fat free milk"], "Skim Milk", cal: 34, p: 3.4, c: 5, f: 0.1, serving: 244, cat: "Dairy")
        add(["yogurt", "greek yogurt"], "Greek Yogurt", cal: 59, p: 10, c: 3.6, f: 0.4, serving: 200, cat: "Dairy")
        add(["cheese", "cheddar", "cheddar cheese"], "Cheddar Cheese", cal: 403, p: 25, c: 1.3, f: 33, serving: 28, cat: "Dairy")
        add(["mozzarella"], "Mozzarella", cal: 280, p: 28, c: 3.1, f: 17, serving: 28, cat: "Dairy")
        add(["cottage cheese"], "Cottage Cheese", cal: 98, p: 11, c: 3.4, f: 4.3, serving: 226, cat: "Dairy")
        add(["butter"], "Butter", cal: 717, p: 0.9, c: 0.1, f: 81, serving: 14, cat: "Dairy")
        add(["cream cheese"], "Cream Cheese", cal: 342, p: 6, c: 4, f: 34, serving: 28, cat: "Dairy")
        
        // ── Legumes & Nuts ──
        add(["almonds", "almond"], "Almonds", cal: 579, p: 21, c: 22, f: 50, serving: 28, cat: "Nuts")
        add(["peanuts", "peanut"], "Peanuts", cal: 567, p: 26, c: 16, f: 49, serving: 28, cat: "Nuts")
        add(["walnuts", "walnut"], "Walnuts", cal: 654, p: 15, c: 14, f: 65, serving: 28, cat: "Nuts")
        add(["cashews", "cashew"], "Cashews", cal: 553, p: 18, c: 30, f: 44, serving: 28, cat: "Nuts")
        add(["peanut butter"], "Peanut Butter", cal: 588, p: 25, c: 20, f: 50, serving: 32, cat: "Nuts")
        add(["almond butter"], "Almond Butter", cal: 614, p: 21, c: 19, f: 56, serving: 32, cat: "Nuts")
        add(["lentils", "dal"], "Lentils (cooked)", cal: 116, p: 9, c: 20, f: 0.4, serving: 198, cat: "Legume")
        add(["chickpeas", "garbanzo"], "Chickpeas (cooked)", cal: 164, p: 9, c: 27, f: 2.6, serving: 164, cat: "Legume")
        add(["black beans"], "Black Beans (cooked)", cal: 132, p: 8.9, c: 24, f: 0.5, serving: 172, cat: "Legume")
        add(["kidney beans"], "Kidney Beans (cooked)", cal: 127, p: 8.7, c: 23, f: 0.5, serving: 177, cat: "Legume")
        
        // ── Common Meals ──
        add(["pizza", "pizza slice"], "Pizza Slice", cal: 266, p: 11, c: 33, f: 10, serving: 107, cat: "Meal")
        add(["hamburger", "burger", "cheeseburger"], "Hamburger", cal: 295, p: 17, c: 24, f: 14, serving: 215, cat: "Meal")
        add(["hot dog"], "Hot Dog", cal: 290, p: 10, c: 24, f: 17, serving: 98, cat: "Meal")
        add(["sandwich", "sub"], "Sandwich", cal: 250, p: 14, c: 28, f: 9, serving: 200, cat: "Meal")
        add(["burrito"], "Burrito", cal: 206, p: 9, c: 26, f: 7, serving: 200, cat: "Meal")
        add(["sushi", "sushi roll"], "Sushi Roll", cal: 140, p: 5, c: 22, f: 3.6, serving: 100, cat: "Meal")
        add(["fried rice"], "Fried Rice", cal: 163, p: 4.5, c: 23, f: 6, serving: 200, cat: "Meal")
        add(["mac and cheese", "macaroni and cheese"], "Mac & Cheese", cal: 164, p: 6, c: 18, f: 7.5, serving: 200, cat: "Meal")
        add(["caesar salad"], "Caesar Salad", cal: 127, p: 6, c: 7, f: 9, serving: 200, cat: "Meal")
        add(["french fries", "fries", "chips"], "French Fries", cal: 312, p: 3.4, c: 41, f: 15, serving: 117, cat: "Meal")
        add(["pancakes", "pancake"], "Pancakes", cal: 227, p: 6, c: 28, f: 10, serving: 77, cat: "Meal")
        add(["waffle", "waffles"], "Waffles", cal: 291, p: 8, c: 33, f: 14, serving: 75, cat: "Meal")
        
        // ── Snacks ──
        add(["protein bar"], "Protein Bar", cal: 373, p: 25, c: 40, f: 13, serving: 60, cat: "Snack")
        add(["chocolate", "dark chocolate"], "Dark Chocolate", cal: 546, p: 5, c: 60, f: 31, serving: 40, cat: "Snack")
        add(["ice cream"], "Ice Cream", cal: 207, p: 3.5, c: 24, f: 11, serving: 132, cat: "Snack")
        add(["popcorn"], "Popcorn (air-popped)", cal: 375, p: 12, c: 74, f: 4.3, serving: 28, cat: "Snack")
        add(["cookie", "cookies"], "Cookie", cal: 488, p: 5, c: 65, f: 24, serving: 30, cat: "Snack")
        add(["chips", "potato chips", "crisps"], "Potato Chips", cal: 536, p: 7, c: 53, f: 35, serving: 28, cat: "Snack")
        add(["trail mix"], "Trail Mix", cal: 462, p: 14, c: 44, f: 29, serving: 40, cat: "Snack")
        
        // ── Beverages ──
        add(["orange juice", "oj"], "Orange Juice", cal: 45, p: 0.7, c: 10, f: 0.2, serving: 248, cat: "Beverage")
        add(["apple juice"], "Apple Juice", cal: 46, p: 0.1, c: 11, f: 0.1, serving: 248, cat: "Beverage")
        add(["coffee", "black coffee"], "Black Coffee", cal: 2, p: 0.3, c: 0, f: 0, serving: 237, cat: "Beverage")
        add(["latte", "cafe latte"], "Latte", cal: 67, p: 3.4, c: 5.3, f: 3.6, serving: 240, cat: "Beverage")
        add(["cappuccino"], "Cappuccino", cal: 56, p: 2.9, c: 4.5, f: 3, serving: 180, cat: "Beverage")
        add(["smoothie", "fruit smoothie"], "Fruit Smoothie", cal: 68, p: 1.2, c: 14, f: 0.8, serving: 250, cat: "Beverage")
        add(["protein shake"], "Protein Shake", cal: 113, p: 20, c: 6, f: 1.5, serving: 350, cat: "Beverage")
        add(["cola", "coke", "soda", "pepsi"], "Cola", cal: 42, p: 0, c: 11, f: 0, serving: 355, cat: "Beverage")
        add(["beer"], "Beer", cal: 43, p: 0.5, c: 3.6, f: 0, serving: 355, cat: "Beverage")
        add(["wine", "red wine", "white wine"], "Wine", cal: 83, p: 0.1, c: 2.6, f: 0, serving: 148, cat: "Beverage")
        
        // ── Oils & Condiments ──
        add(["olive oil"], "Olive Oil", cal: 884, p: 0, c: 0, f: 100, serving: 14, cat: "Oil")
        add(["honey"], "Honey", cal: 304, p: 0.3, c: 82, f: 0, serving: 21, cat: "Condiment")
        add(["ketchup"], "Ketchup", cal: 112, p: 1.7, c: 26, f: 0.1, serving: 17, cat: "Condiment")
        add(["mayonnaise", "mayo"], "Mayonnaise", cal: 680, p: 1, c: 0.6, f: 75, serving: 15, cat: "Condiment")
        add(["hummus"], "Hummus", cal: 166, p: 8, c: 14, f: 10, serving: 62, cat: "Condiment")
        
        // ── Indian Cuisine ──
        add(["naan", "naan bread"], "Naan Bread", cal: 262, p: 9, c: 43, f: 5, serving: 90, cat: "Grain")
        add(["roti", "chapati"], "Roti/Chapati", cal: 120, p: 3.5, c: 18, f: 3.7, serving: 40, cat: "Grain")
        add(["paneer", "cottage cheese indian"], "Paneer", cal: 265, p: 18, c: 1.2, f: 21, serving: 100, cat: "Protein")
        add(["biryani", "chicken biryani"], "Biryani", cal: 146, p: 6.5, c: 18, f: 5, serving: 250, cat: "Meal")
        add(["butter chicken", "murgh makhani"], "Butter Chicken", cal: 147, p: 12, c: 6, f: 8.5, serving: 200, cat: "Meal")
        add(["dal", "daal", "yellow dal"], "Dal", cal: 104, p: 7, c: 16, f: 1.5, serving: 200, cat: "Meal")
        add(["samosa", "samosas"], "Samosa", cal: 262, p: 5, c: 30, f: 14, serving: 80, cat: "Snack")
        add(["dosa"], "Dosa", cal: 133, p: 4, c: 19, f: 5, serving: 100, cat: "Meal")
        add(["idli", "idlis"], "Idli", cal: 58, p: 2, c: 12, f: 0.2, serving: 40, cat: "Meal")
        add(["paratha"], "Paratha", cal: 260, p: 5, c: 30, f: 13, serving: 80, cat: "Grain")
        
        // ── Asian Cuisine ──
        add(["ramen"], "Ramen", cal: 190, p: 8, c: 26, f: 6, serving: 400, cat: "Meal")
        add(["pad thai"], "Pad Thai", cal: 155, p: 7, c: 19, f: 5.5, serving: 250, cat: "Meal")
        add(["dim sum", "dumpling", "dumplings"], "Dumplings", cal: 171, p: 8, c: 20, f: 6.5, serving: 100, cat: "Meal")
        add(["spring roll", "spring rolls"], "Spring Roll", cal: 154, p: 4, c: 18, f: 7, serving: 64, cat: "Snack")
        add(["miso soup"], "Miso Soup", cal: 21, p: 1.3, c: 2.6, f: 0.6, serving: 240, cat: "Meal")
        add(["edamame"], "Edamame", cal: 121, p: 12, c: 9, f: 5, serving: 155, cat: "Snack")
        
        // ── Mexican ──
        add(["taco", "tacos"], "Taco", cal: 210, p: 9, c: 21, f: 10, serving: 100, cat: "Meal")
        add(["quesadilla"], "Quesadilla", cal: 274, p: 12, c: 22, f: 15, serving: 150, cat: "Meal")
        add(["guacamole"], "Guacamole", cal: 160, p: 2, c: 9, f: 15, serving: 100, cat: "Condiment")
        add(["nachos"], "Nachos with Cheese", cal: 346, p: 9, c: 36, f: 19, serving: 113, cat: "Snack")
        
        return db
    }()
    
    private init() {}
    
    // MARK: - Lookup
    
    /// Attempt to find a local nutrition match for the given food name.
    /// Returns nil if no match — caller should fall back to AI.
    func lookup(_ foodName: String) -> NutritionInfo? {
        let normalized = foodName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exact match first
        if let exact = database[normalized] {
            return exact
        }
        
        // Try matching with common prefixes stripped ("grilled ", "fried ", etc.)
        let prefixes = ["grilled ", "baked ", "roasted ", "steamed ", "fried ", "boiled ", "raw ", "fresh ", "cooked ", "sliced ", "chopped ", "diced "]
        for prefix in prefixes {
            if normalized.hasPrefix(prefix) {
                let stripped = String(normalized.dropFirst(prefix.count))
                if let match = database[stripped] {
                    return match
                }
            }
        }
        
        // Try contains-based matching for compound names ("chicken breast salad" → "chicken breast")
        for (key, info) in database {
            if normalized.contains(key) && key.count >= 4 {
                return info
            }
        }
        
        return nil
    }
    
    /// Get nutrition for a specific serving (returns per-serving values).
    func nutritionForServing(_ foodName: String, servingGrams: Double? = nil) -> (calories: Int, protein: Double, carbs: Double, fat: Double)? {
        guard let info = lookup(foodName) else { return nil }
        
        let grams = servingGrams ?? info.typicalServingGrams
        let multiplier = grams / 100.0
        
        return (
            calories: Int(info.caloriesPer100g * multiplier),
            protein: round(info.proteinPer100g * multiplier * 10) / 10,
            carbs: round(info.carbsPer100g * multiplier * 10) / 10,
            fat: round(info.fatPer100g * multiplier * 10) / 10
        )
    }
    
    /// Number of foods in the database.
    var count: Int { database.count }
}
