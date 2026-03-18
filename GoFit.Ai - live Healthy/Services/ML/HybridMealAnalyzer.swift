import Foundation
import UIKit

// MARK: - Hybrid Meal Analyzer
/// The brain of GoFit's self-learning food recognition system.
///
/// Strategy:
///   1. Try LOCAL classification first (Vision + Core ML + learned data) — FREE, instant
///   2. Only fall back to OpenAI API if local confidence is too low — costs money, slow
///   3. After every API response, feed the result back to MealDataCollector for learning
///
/// Over time, as the dataset grows:
///   - Week 1:  ~10% of scans handled locally (only very obvious foods)
///   - Month 1: ~30-40% local (common foods the user eats regularly)
///   - Month 3: ~60%+ local (with a trained custom model)
///   - Month 6: ~80%+ local (the model keeps getting better)
///
/// The system is self-improving: every API call makes the local model smarter,
/// so eventually you stop needing the API at all.
@MainActor
final class HybridMealAnalyzer: ObservableObject {
    static let shared = HybridMealAnalyzer()
    
    private let localClassifier = LocalFoodClassifier.shared
    private let dataCollector = MealDataCollector.shared
    
    /// Confidence threshold for accepting local results without API verification.
    /// Starts conservative and can be lowered as the local model improves.
    private let localAcceptanceThreshold: Float = 0.55
    
    @Published var lastAnalysisSource: AnalysisSource = .none
    @Published var localHitRate: Double = 0  // Percentage of scans handled locally
    
    enum AnalysisSource: String {
        case none = "—"
        case local = "On-Device"
        case api = "Cloud AI"
        case hybrid = "Verified"  // Local result verified by API
    }
    
    // Track local vs API usage for stats
    private let statsKey = "HybridAnalyzerStats"
    
    struct AnalyzerStats: Codable {
        var totalScans: Int = 0
        var localScans: Int = 0
        var apiScans: Int = 0
        var apiSavings: Double = 0  // Estimated $ saved by local scans
    }
    
    private init() {
        loadStats()
    }
    
    // MARK: - Main Analysis Entry Point
    
    /// Analyze a food image using the hybrid local-first approach.
    /// Returns a ServerMealResponse compatible with the existing UI.
    ///
    /// - Parameters:
    ///   - image: The food photo
    ///   - imageData: Compressed JPEG data for API fallback
    ///   - userId: User's ID for API auth
    /// - Returns: ServerMealResponse with parsed items
    func analyze(image: UIImage, imageData: Data, userId: String?) async throws -> (response: ServerMealResponse, source: AnalysisSource) {
        
        // Step 1: Try local classification (free & instant)
        if let localResults = await localClassifier.classify(image: image) {
            // Check if we're confident enough in the local results
            let avgConfidence = localResults.reduce(Float(0)) { $0 + localClassifier.effectiveConfidence(for: $1) } / Float(localResults.count)
            
            if avgConfidence >= localAcceptanceThreshold {
                // 🎉 Local classification is confident — no API call needed!
                let response = buildResponse(from: localResults)
                
                // Record this scan to keep growing our dataset
                let parsedItems = response.parsedItems ?? []
                dataCollector.record(image: image, items: parsedItems, wasEdited: false)
                
                // Update stats
                var stats = loadRawStats()
                stats.totalScans += 1
                stats.localScans += 1
                stats.apiSavings += 0.05 // Estimated $0.05 saved per avoided API call
                saveStats(stats)
                updateHitRate(stats)
                
                await MainActor.run {
                    lastAnalysisSource = .local
                }
                
                #if DEBUG
                print("✅ HybridAnalyzer: LOCAL classification accepted (confidence: \(String(format: "%.0f", avgConfidence * 100))%)")
                print("   💰 API call saved! Total savings: $\(String(format: "%.2f", stats.apiSavings))")
                #endif
                
                return (response, .local)
            }
            
            #if DEBUG
            print("⚠️ HybridAnalyzer: Local confidence too low (\(String(format: "%.0f", avgConfidence * 100))%), falling back to API")
            #endif
        }
        
        // Step 2: Fall back to API (costs money, but accurate)
        let apiResponse = try await NetworkManager.shared.uploadMealImage(
            data: imageData,
            filename: "meal.jpg",
            userId: userId
        )
        
        // Step 3: Feed API result back to collector for learning 🧠
        if let items = apiResponse.parsedItems, !items.isEmpty {
            dataCollector.record(image: image, items: items, wasEdited: false)
        }
        
        // Update stats
        var stats = loadRawStats()
        stats.totalScans += 1
        stats.apiScans += 1
        saveStats(stats)
        updateHitRate(stats)
        
        await MainActor.run {
            lastAnalysisSource = .api
        }
        
        #if DEBUG
        print("☁️ HybridAnalyzer: Used API (local hit rate: \(String(format: "%.0f", localHitRate))%)")
        #endif
        
        return (apiResponse, .api)
    }
    
    // MARK: - Build Response from Local Results
    
    /// Convert local classification results into the same ServerMealResponse format
    /// that the rest of the app expects.
    private func buildResponse(from results: [LocalFoodClassifier.ClassificationResult]) -> ServerMealResponse {
        let parsedItems = results.map { result in
            ParsedItem(
                name: result.foodName,
                calories: Double(result.calories),
                protein: result.protein,
                carbs: result.carbs,
                fat: result.fat,
                sugar: result.sugar,
                portionSize: result.portionSize,
                confidence: Double(result.confidence)
            )
        }
        
        return ServerMealResponse(
            mealId: "local_\(UUID().uuidString.prefix(8))",
            parsedItems: parsedItems,
            recommendations: nil
        )
    }
    
    // MARK: - Record User Edits (Gold Standard Training Data)
    
    /// Call this when the user edits AI results before logging.
    /// User-corrected labels are the highest quality training data.
    func recordUserCorrection(image: UIImage, correctedItems: [EditableParsedItem]) {
        dataCollector.recordEdited(image: image, items: correctedItems)
        
        #if DEBUG
        print("✏️ HybridAnalyzer: Recorded user correction (\(correctedItems.count) items) — gold-standard training data!")
        #endif
    }
    
    // MARK: - Statistics
    
    private func loadRawStats() -> AnalyzerStats {
        guard let data = UserDefaults.standard.data(forKey: statsKey),
              let stats = try? JSONDecoder().decode(AnalyzerStats.self, from: data) else {
            return AnalyzerStats()
        }
        return stats
    }
    
    private func saveStats(_ stats: AnalyzerStats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: statsKey)
        }
    }
    
    private func loadStats() {
        let stats = loadRawStats()
        updateHitRate(stats)
    }
    
    private func updateHitRate(_ stats: AnalyzerStats) {
        if stats.totalScans > 0 {
            localHitRate = Double(stats.localScans) / Double(stats.totalScans) * 100
        }
    }
    
    /// Get comprehensive stats for the dashboard.
    var analyzerStats: AnalyzerStats {
        loadRawStats()
    }
    
    /// Get data collector stats.
    var datasetStats: MealDataCollector.DatasetStats {
        dataCollector.stats
    }
    
    /// Reset all stats (for debugging/testing).
    func resetStats() {
        UserDefaults.standard.removeObject(forKey: statsKey)
        localHitRate = 0
        lastAnalysisSource = .none
    }
}
