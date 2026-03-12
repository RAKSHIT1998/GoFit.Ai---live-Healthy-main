import Foundation

/// AI-powered nutrition lookup - user types food name + portion → AI returns nutrition data
@MainActor
class AINutritionLookup: ObservableObject {
    static let shared = AINutritionLookup()
    
    @Published var isLoading = false
    @Published var error: String?
    
    private init() {}
    
    struct NutritionResult {
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let sugar: Double
    }
    
    /// Look up nutrition for a food + portion using the AI backend
    func lookup(foodName: String, portion: String) async -> NutritionResult? {
        guard !foodName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        // First try the backend AI lookup
        if let result = await fetchFromBackend(foodName: foodName, portion: portion) {
            return result
        }
        
        // Fallback to local database
        return localLookup(foodName: foodName, portion: portion)
    }
    
    // MARK: - Backend AI Lookup
    private func fetchFromBackend(foodName: String, portion: String) async -> NutritionResult? {
        guard let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty else { return nil }
        
        do {
            struct AIRequest: Codable {
                let foodName: String
                let portion: String
            }
            
            struct AIResponse: Codable {
                let calories: Double?
                let protein: Double?
                let carbs: Double?
                let fat: Double?
                let sugar: Double?
            }
            
            let requestBody = AIRequest(foodName: foodName, portion: portion)
            let bodyData = try JSONEncoder().encode(requestBody)
            
            let response: AIResponse = try await NetworkManager.shared.request(
                "meals/ai-nutrition-lookup",
                method: "POST",
                body: bodyData
            )
            
            return NutritionResult(
                calories: response.calories ?? 0,
                protein: response.protein ?? 0,
                carbs: response.carbs ?? 0,
                fat: response.fat ?? 0,
                sugar: response.sugar ?? 0
            )
        } catch {
            print("⚠️ AI nutrition backend lookup failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Local Fallback Database
    /// Best-effort local lookup from a common foods database
    private func localLookup(foodName: String, portion: String) -> NutritionResult? {
        let name = foodName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let portionMultiplier = parsePortionMultiplier(portion)
        
        // Common foods database (per 100g / standard serving)
        let database: [String: NutritionResult] = [
            // Grains & Bread
            "rice": NutritionResult(calories: 130, protein: 2.7, carbs: 28, fat: 0.3, sugar: 0),
            "white rice": NutritionResult(calories: 130, protein: 2.7, carbs: 28, fat: 0.3, sugar: 0),
            "brown rice": NutritionResult(calories: 112, protein: 2.3, carbs: 24, fat: 0.8, sugar: 0.4),
            "bread": NutritionResult(calories: 265, protein: 9, carbs: 49, fat: 3.2, sugar: 5),
            "whole wheat bread": NutritionResult(calories: 247, protein: 13, carbs: 41, fat: 3.4, sugar: 6),
            "pasta": NutritionResult(calories: 131, protein: 5, carbs: 25, fat: 1.1, sugar: 0.6),
            "noodles": NutritionResult(calories: 138, protein: 4.5, carbs: 25, fat: 2.1, sugar: 0.6),
            "oatmeal": NutritionResult(calories: 68, protein: 2.4, carbs: 12, fat: 1.4, sugar: 0.5),
            "oats": NutritionResult(calories: 68, protein: 2.4, carbs: 12, fat: 1.4, sugar: 0.5),
            "roti": NutritionResult(calories: 297, protein: 9.8, carbs: 50, fat: 7.5, sugar: 3.5),
            "chapati": NutritionResult(calories: 297, protein: 9.8, carbs: 50, fat: 7.5, sugar: 3.5),
            "naan": NutritionResult(calories: 262, protein: 8.7, carbs: 45, fat: 5.1, sugar: 3.6),
            
            // Proteins
            "chicken": NutritionResult(calories: 239, protein: 27, carbs: 0, fat: 14, sugar: 0),
            "chicken breast": NutritionResult(calories: 165, protein: 31, carbs: 0, fat: 3.6, sugar: 0),
            "grilled chicken": NutritionResult(calories: 165, protein: 31, carbs: 0, fat: 3.6, sugar: 0),
            "egg": NutritionResult(calories: 155, protein: 13, carbs: 1.1, fat: 11, sugar: 1.1),
            "eggs": NutritionResult(calories: 155, protein: 13, carbs: 1.1, fat: 11, sugar: 1.1),
            "boiled egg": NutritionResult(calories: 155, protein: 13, carbs: 1.1, fat: 11, sugar: 1.1),
            "salmon": NutritionResult(calories: 208, protein: 20, carbs: 0, fat: 13, sugar: 0),
            "fish": NutritionResult(calories: 206, protein: 22, carbs: 0, fat: 12, sugar: 0),
            "tofu": NutritionResult(calories: 76, protein: 8, carbs: 1.9, fat: 4.8, sugar: 0.7),
            "paneer": NutritionResult(calories: 265, protein: 18, carbs: 1.2, fat: 20, sugar: 1.2),
            "steak": NutritionResult(calories: 271, protein: 26, carbs: 0, fat: 18, sugar: 0),
            "turkey": NutritionResult(calories: 189, protein: 29, carbs: 0, fat: 7.4, sugar: 0),
            "shrimp": NutritionResult(calories: 99, protein: 24, carbs: 0.2, fat: 0.3, sugar: 0),
            "tuna": NutritionResult(calories: 132, protein: 28, carbs: 0, fat: 1.3, sugar: 0),
            
            // Dairy
            "milk": NutritionResult(calories: 42, protein: 3.4, carbs: 5, fat: 1, sugar: 5),
            "yogurt": NutritionResult(calories: 59, protein: 10, carbs: 3.6, fat: 0.4, sugar: 3.2),
            "greek yogurt": NutritionResult(calories: 59, protein: 10, carbs: 3.6, fat: 0.4, sugar: 3.2),
            "cheese": NutritionResult(calories: 402, protein: 25, carbs: 1.3, fat: 33, sugar: 0.5),
            "butter": NutritionResult(calories: 717, protein: 0.9, carbs: 0.1, fat: 81, sugar: 0.1),
            
            // Fruits
            "apple": NutritionResult(calories: 52, protein: 0.3, carbs: 14, fat: 0.2, sugar: 10),
            "banana": NutritionResult(calories: 89, protein: 1.1, carbs: 23, fat: 0.3, sugar: 12),
            "orange": NutritionResult(calories: 47, protein: 0.9, carbs: 12, fat: 0.1, sugar: 9.4),
            "mango": NutritionResult(calories: 60, protein: 0.8, carbs: 15, fat: 0.4, sugar: 14),
            "grapes": NutritionResult(calories: 69, protein: 0.7, carbs: 18, fat: 0.2, sugar: 16),
            "strawberries": NutritionResult(calories: 32, protein: 0.7, carbs: 7.7, fat: 0.3, sugar: 4.9),
            "blueberries": NutritionResult(calories: 57, protein: 0.7, carbs: 14, fat: 0.3, sugar: 10),
            "watermelon": NutritionResult(calories: 30, protein: 0.6, carbs: 7.6, fat: 0.2, sugar: 6.2),
            "pineapple": NutritionResult(calories: 50, protein: 0.5, carbs: 13, fat: 0.1, sugar: 10),
            "avocado": NutritionResult(calories: 160, protein: 2, carbs: 8.5, fat: 15, sugar: 0.7),
            
            // Vegetables
            "salad": NutritionResult(calories: 20, protein: 1.5, carbs: 3.3, fat: 0.2, sugar: 1.3),
            "broccoli": NutritionResult(calories: 34, protein: 2.8, carbs: 7, fat: 0.4, sugar: 1.7),
            "spinach": NutritionResult(calories: 23, protein: 2.9, carbs: 3.6, fat: 0.4, sugar: 0.4),
            "potato": NutritionResult(calories: 77, protein: 2, carbs: 17, fat: 0.1, sugar: 0.8),
            "sweet potato": NutritionResult(calories: 86, protein: 1.6, carbs: 20, fat: 0.1, sugar: 4.2),
            "corn": NutritionResult(calories: 86, protein: 3.3, carbs: 19, fat: 1.2, sugar: 3.2),
            
            // Common meals
            "pizza": NutritionResult(calories: 266, protein: 11, carbs: 33, fat: 10, sugar: 3.6),
            "burger": NutritionResult(calories: 295, protein: 17, carbs: 24, fat: 14, sugar: 5),
            "sandwich": NutritionResult(calories: 250, protein: 12, carbs: 30, fat: 9, sugar: 4),
            "biryani": NutritionResult(calories: 250, protein: 15, carbs: 35, fat: 8, sugar: 1),
            "dal": NutritionResult(calories: 116, protein: 9, carbs: 20, fat: 0.4, sugar: 0.6),
            "curry": NutritionResult(calories: 150, protein: 10, carbs: 12, fat: 8, sugar: 3),
            "soup": NutritionResult(calories: 60, protein: 3, carbs: 8, fat: 2, sugar: 2),
            "fried rice": NutritionResult(calories: 163, protein: 4.3, carbs: 23, fat: 6, sugar: 0.8),
            "tacos": NutritionResult(calories: 210, protein: 9, carbs: 21, fat: 10, sugar: 2),
            "sushi": NutritionResult(calories: 150, protein: 6, carbs: 22, fat: 4, sugar: 4),
            "dosa": NutritionResult(calories: 168, protein: 4, carbs: 27, fat: 5, sugar: 1),
            "idli": NutritionResult(calories: 58, protein: 2, carbs: 12, fat: 0.2, sugar: 0.3),
            "paratha": NutritionResult(calories: 260, protein: 5, carbs: 36, fat: 10, sugar: 1),
            
            // Snacks & Sweets
            "chips": NutritionResult(calories: 536, protein: 7, carbs: 53, fat: 35, sugar: 0.3),
            "chocolate": NutritionResult(calories: 546, protein: 5, carbs: 60, fat: 31, sugar: 48),
            "ice cream": NutritionResult(calories: 207, protein: 3.5, carbs: 24, fat: 11, sugar: 21),
            "cake": NutritionResult(calories: 265, protein: 4, carbs: 38, fat: 11, sugar: 22),
            "cookie": NutritionResult(calories: 502, protein: 5, carbs: 64, fat: 25, sugar: 32),
            "donut": NutritionResult(calories: 452, protein: 5, carbs: 51, fat: 25, sugar: 22),
            "popcorn": NutritionResult(calories: 375, protein: 11, carbs: 74, fat: 4.5, sugar: 0.9),
            "nuts": NutritionResult(calories: 607, protein: 20, carbs: 21, fat: 54, sugar: 4),
            "almonds": NutritionResult(calories: 579, protein: 21, carbs: 22, fat: 50, sugar: 4.4),
            "peanut butter": NutritionResult(calories: 588, protein: 25, carbs: 20, fat: 50, sugar: 9),
            
            // Drinks
            "coffee": NutritionResult(calories: 2, protein: 0.3, carbs: 0, fat: 0, sugar: 0),
            "latte": NutritionResult(calories: 135, protein: 7, carbs: 13, fat: 6, sugar: 12),
            "smoothie": NutritionResult(calories: 135, protein: 3, carbs: 28, fat: 1, sugar: 22),
            "protein shake": NutritionResult(calories: 150, protein: 25, carbs: 8, fat: 2, sugar: 3),
        ]
        
        // Try exact match first, then partial match
        if let result = database[name] {
            return applyMultiplier(result, portionMultiplier)
        }
        
        // Partial match
        for (key, result) in database {
            if name.contains(key) || key.contains(name) {
                return applyMultiplier(result, portionMultiplier)
            }
        }
        
        return nil
    }
    
    private func applyMultiplier(_ result: NutritionResult, _ multiplier: Double) -> NutritionResult {
        NutritionResult(
            calories: result.calories * multiplier,
            protein: result.protein * multiplier,
            carbs: result.carbs * multiplier,
            fat: result.fat * multiplier,
            sugar: result.sugar * multiplier
        )
    }
    
    private func parsePortionMultiplier(_ portion: String) -> Double {
        let text = portion.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return 1.0 }
        
        // Extract numbers
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let number = Double(numbers) ?? 1.0
        
        // Common portion references
        if text.contains("cup") { return number * 2.0 } // 1 cup ≈ 200g ≈ 2x (100g base)
        if text.contains("bowl") { return number * 3.0 } // 1 bowl ≈ 300g
        if text.contains("plate") { return number * 3.5 }
        if text.contains("slice") { return number * 0.5 }
        if text.contains("piece") { return number * 1.0 }
        if text.contains("serving") { return number * 1.0 }
        if text.contains("tablespoon") || text.contains("tbsp") { return number * 0.15 }
        if text.contains("teaspoon") || text.contains("tsp") { return number * 0.05 }
        if text.contains("handful") { return number * 0.3 }
        if text.contains("small") { return number * 0.7 }
        if text.contains("large") { return number * 1.5 }
        if text.contains("medium") { return number * 1.0 }
        
        // Grams: e.g. "200g" → 200/100 = 2x
        if text.contains("g") {
            return number / 100.0
        }
        
        // ml → rough conversion (mostly for liquids)
        if text.contains("ml") {
            return number / 100.0
        }
        
        // Just a number like "2" → 2 servings
        if number > 0 { return number }
        
        return 1.0
    }
}
