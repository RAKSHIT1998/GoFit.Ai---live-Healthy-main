import Foundation
import UIKit
import Vision
import CoreML

// MARK: - Local Food Classifier
/// On-device food image classifier that works WITHOUT any API calls.
///
/// Strategy (layered, from cheapest to most expensive):
///   1. **Learned Labels** — If we've seen this exact food before (via MealDataCollector),
///      use the stored nutrition data directly. Zero cost.
///   2. **Vision Framework** — Apple's built-in VNClassifyImageRequest can recognize
///      1000+ objects including many foods. Map result → LocalNutritionDatabase.
///   3. **Custom Core ML Model** — When you eventually train your own model from collected
///      data, drop the .mlmodel file into the bundle and it gets used automatically.
///   4. **Fall through** — Returns nil, caller should use the API.
///
/// The more users scan, the smarter this gets — without spending a penny on OpenAI.
final class LocalFoodClassifier {
    static let shared = LocalFoodClassifier()
    
    /// Minimum confidence required to use a local classification (0–1).
    /// Higher = more conservative (fewer false positives, more API fallbacks).
    /// Lower  = more aggressive (saves more money, slightly less accurate).
    private let minimumConfidence: Float = 0.40
    
    /// Result of a local classification attempt.
    struct ClassificationResult {
        let foodName: String
        let confidence: Float        // 0.0 – 1.0
        let calories: Int
        let protein: Double
        let carbs: Double
        let fat: Double
        let sugar: Double
        let source: ClassificationSource
        let portionSize: String?
    }
    
    enum ClassificationSource: String {
        case learnedFromScans = "Learned"     // From our own collected data
        case visionFramework  = "On-Device AI" // Apple's Vision framework
        case customModel      = "GoFit AI"     // Our trained Core ML model
    }
    
    private let collector = MealDataCollector.shared
    private let nutritionDB = LocalNutritionDatabase.shared
    
    /// Optional custom Core ML model (loaded from bundle if available).
    private var customModel: VNCoreMLModel?
    
    private init() {
        loadCustomModelIfAvailable()
    }
    
    // MARK: - Main Classification Pipeline
    
    /// Attempt to classify a food image locally. Returns nil if not confident enough.
    /// This is the main entry point — called by HybridMealAnalyzer before falling back to API.
    func classify(image: UIImage) async -> [ClassificationResult]? {
        
        // Layer 1: Try custom Core ML model first (best accuracy if we've trained one)
        if let customResults = await classifyWithCustomModel(image) {
            #if DEBUG
            print("🤖 LocalFoodClassifier: Custom model identified \(customResults.count) item(s)")
            #endif
            return customResults
        }
        
        // Layer 2: Apple Vision framework classification
        if let visionResults = await classifyWithVision(image) {
            #if DEBUG
            print("👁️ LocalFoodClassifier: Vision framework identified \(visionResults.count) item(s)")
            #endif
            return visionResults
        }
        
        // Layer 3: Check if the image resembles any of our collected training data
        // (This is a simple similarity check — not as good as a trained model)
        if let learnedResults = classifyFromLearnedData(image) {
            #if DEBUG
            print("📚 LocalFoodClassifier: Matched from learned data: \(learnedResults.count) item(s)")
            #endif
            return learnedResults
        }
        
        return nil // Not confident — caller should fall back to API
    }
    
    // MARK: - Layer 1: Custom Core ML Model
    
    private func loadCustomModelIfAvailable() {
        // Look for a custom food classifier model in the app bundle
        // When you train one with Create ML, add GoFitFoodClassifier.mlmodelc to the bundle
        guard let modelURL = Bundle.main.url(forResource: "GoFitFoodClassifier", withExtension: "mlmodelc") else {
            #if DEBUG
            print("ℹ️ No custom GoFitFoodClassifier.mlmodelc found in bundle (will use Vision framework)")
            #endif
            return
        }
        
        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            customModel = try VNCoreMLModel(for: mlModel)
            print("✅ Loaded custom GoFitFoodClassifier model")
        } catch {
            print("⚠️ Failed to load custom model: \(error)")
        }
    }
    
    private func classifyWithCustomModel(_ image: UIImage) async -> [ClassificationResult]? {
        guard let model = customModel, let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                guard let self = self,
                      let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let confident = results.filter { $0.confidence >= self.minimumConfidence }
                if confident.isEmpty {
                    continuation.resume(returning: nil)
                    return
                }
                
                let classifications = confident.compactMap { obs -> ClassificationResult? in
                    let foodName = obs.identifier
                    guard let nutrition = self.nutritionDB.nutritionForServing(foodName) else { return nil }
                    
                    return ClassificationResult(
                        foodName: foodName.capitalized,
                        confidence: obs.confidence,
                        calories: nutrition.calories,
                        protein: nutrition.protein,
                        carbs: nutrition.carbs,
                        fat: nutrition.fat,
                        sugar: 0,
                        source: .customModel,
                        portionSize: "1 serving"
                    )
                }
                
                continuation.resume(returning: classifications.isEmpty ? nil : classifications)
            }
            
            request.imageCropAndScaleOption = .centerCrop
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    // MARK: - Layer 2: Apple Vision Framework
    
    /// Use Apple's built-in image classifier to identify food items.
    /// VNClassifyImageRequest can recognize 1000+ categories including many foods.
    private func classifyWithVision(_ image: UIImage) async -> [ClassificationResult]? {
        guard let cgImage = image.cgImage else { return nil }
        
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { [weak self] request, error in
                guard let self = self,
                      let results = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Filter for food-related classifications with decent confidence
                let foodResults = results.filter { obs in
                    obs.confidence >= self.minimumConfidence && self.isFoodRelated(obs.identifier)
                }
                
                if foodResults.isEmpty {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Map Vision labels to our nutrition database
                let classifications = foodResults.prefix(3).compactMap { obs -> ClassificationResult? in
                    let mappedName = self.mapVisionLabel(obs.identifier)
                    guard let nutrition = self.nutritionDB.nutritionForServing(mappedName) else { return nil }
                    
                    return ClassificationResult(
                        foodName: mappedName.capitalized,
                        confidence: obs.confidence,
                        calories: nutrition.calories,
                        protein: nutrition.protein,
                        carbs: nutrition.carbs,
                        fat: nutrition.fat,
                        sugar: 0,
                        source: .visionFramework,
                        portionSize: "1 serving"
                    )
                }
                
                continuation.resume(returning: classifications.isEmpty ? nil : classifications)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    // MARK: - Layer 3: Learned Data Matching
    
    /// Check if we've collected enough examples of common foods to provide a reasonable match.
    /// This uses the food frequency data from MealDataCollector to match high-frequency foods.
    private func classifyFromLearnedData(_ image: UIImage) -> [ClassificationResult]? {
        // This is a placeholder for more sophisticated matching.
        // For now, we only use this path when we have a custom model — the Vision
        // framework in Layer 2 handles the actual image classification.
        // As the dataset grows, this can be enhanced with feature vector comparison.
        return nil
    }
    
    // MARK: - Vision Label Mapping
    
    /// Map Apple Vision classification labels to our food database names.
    /// Vision uses labels like "pizza", "banana", "hot_dog", "ice_cream" etc.
    private let visionToFoodMap: [String: String] = [
        // Fruits
        "banana": "banana",
        "orange": "orange",
        "apple": "apple",
        "strawberry": "strawberry",
        "pineapple": "pineapple",
        "lemon": "lemon",
        "fig": "fig",
        "pomegranate": "pomegranate",
        "granny_smith": "apple",
        
        // Meals & Prepared Food
        "pizza": "pizza",
        "hamburger": "hamburger",
        "cheeseburger": "hamburger",
        "hot_dog": "hot dog",
        "french_loaf": "bread",
        "pretzel": "pretzel",
        "bagel": "bagel",
        "burrito": "burrito",
        "taco": "taco",
        "sushi": "sushi",
        "plate": "meal",
        "dinner": "meal",
        "guacamole": "guacamole",
        "meat_loaf": "ground beef",
        "carbonara": "pasta",
        "spaghetti_squash": "pasta",
        
        // Vegetables & Salad
        "broccoli": "broccoli",
        "cauliflower": "cauliflower",
        "bell_pepper": "bell pepper",
        "mushroom": "mushroom",
        "corn": "corn",
        "cucumber": "cucumber",
        "head_cabbage": "lettuce",
        
        // Desserts & Snacks
        "ice_cream": "ice cream",
        "chocolate_sauce": "dark chocolate",
        "cup_cake": "cookie",
        "dough": "cookie",
        "waffle": "waffles",
        
        // Beverages
        "espresso": "coffee",
        "cup": "coffee",
        "beer_glass": "beer",
        "wine_bottle": "wine",
        "red_wine": "wine",
        "eggnog": "smoothie",
        
        // Proteins
        "meat": "beef",
        "pork": "pork",
        "hen": "chicken",
        "egg": "egg",
    ]
    
    private func mapVisionLabel(_ label: String) -> String {
        let normalized = label.lowercased().replacingOccurrences(of: " ", with: "_")
        return visionToFoodMap[normalized] ?? label.replacingOccurrences(of: "_", with: " ")
    }
    
    /// Food-related Vision categories (Apple's classifier labels food items with these).
    private let foodKeywords: Set<String> = [
        "pizza", "hamburger", "cheeseburger", "hot_dog", "burrito", "taco", "sushi",
        "banana", "orange", "apple", "strawberry", "pineapple", "lemon", "fig",
        "broccoli", "cauliflower", "bell_pepper", "mushroom", "corn", "cucumber",
        "ice_cream", "chocolate", "cup_cake", "waffle", "pretzel", "bagel",
        "espresso", "beer_glass", "wine_bottle", "red_wine", "eggnog",
        "meat_loaf", "carbonara", "guacamole", "french_loaf", "dough",
        "plate", "dinner", "meat", "pork", "hen", "egg", "pomegranate",
        "granny_smith", "head_cabbage", "spaghetti_squash",
    ]
    
    private func isFoodRelated(_ label: String) -> Bool {
        let normalized = label.lowercased().replacingOccurrences(of: " ", with: "_")
        return foodKeywords.contains(normalized)
    }
    
    // MARK: - Confidence Thresholds
    
    /// Dynamically adjust confidence based on how many samples we've collected for a food.
    /// More data = more trust in local classification.
    func effectiveConfidence(for result: ClassificationResult) -> Float {
        let sampleCount = collector.sampleCount(for: result.foodName.lowercased())
        
        // Bonus confidence based on training data volume
        let dataBonus: Float
        switch sampleCount {
        case 0..<5:   dataBonus = 0      // Not enough data
        case 5..<20:  dataBonus = 0.05   // Some data
        case 20..<50: dataBonus = 0.10   // Good data
        default:      dataBonus = 0.15   // Excellent data
        }
        
        return min(1.0, result.confidence + dataBonus)
    }
}
