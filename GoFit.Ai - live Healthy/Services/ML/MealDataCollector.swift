import Foundation
import UIKit

// MARK: - Meal Data Collector
/// Silently collects (image, nutrition-labels) pairs from every successful meal scan.
/// This builds a proprietary training dataset on-device that can later be exported
/// to train a custom Core ML food classifier — making GoFit fully independent from OpenAI.
///
/// Data flow:
///   1. User scans meal → OpenAI returns food labels + nutrition
///   2. MealDataCollector.record(image, result) saves both to disk
///   3. Over time, dataset grows: 100 → 1,000 → 10,000+ labeled food images
///   4. Export to Create ML format → train custom model → ship as .mlmodel OTA update
///   5. LocalFoodClassifier uses the model → API calls drop to near zero
///
/// Privacy: All data stays on-device. Nothing is uploaded without explicit user consent.
final class MealDataCollector {
    static let shared = MealDataCollector()
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.gofitai.mealdata", qos: .utility)
    
    private var baseDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("MealTrainingData")
    }
    
    private var imagesDirectory: URL {
        baseDirectory.appendingPathComponent("images")
    }
    
    private var labelsDirectory: URL {
        baseDirectory.appendingPathComponent("labels")
    }
    
    private var manifestURL: URL {
        baseDirectory.appendingPathComponent("manifest.json")
    }
    
    private init() {
        setupDirectories()
    }
    
    // MARK: - Setup
    
    private func setupDirectories() {
        for dir in [baseDirectory, imagesDirectory, labelsDirectory] {
            if !fileManager.fileExists(atPath: dir.path) {
                try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Data Collection Entry
    
    /// A single labeled food sample for training.
    struct FoodSample: Codable {
        let id: String
        let timestamp: Date
        let foodName: String        // Primary label (e.g., "Chicken Biryani")
        let category: String?       // Optional category (e.g., "Meal", "Fruit")
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let sugar: Double
        let portionSize: String?
        let confidence: Double?     // Original AI confidence
        let imageFileName: String   // Reference to saved JPEG
        let wasUserEdited: Bool     // True if user corrected the AI result (gold-standard label)
    }
    
    /// Dataset manifest — tracks all collected samples.
    struct DatasetManifest: Codable {
        var version: Int
        var totalSamples: Int
        var uniqueFoods: Int
        var lastUpdated: Date
        var foodFrequency: [String: Int]  // food name → count
        var samples: [FoodSample]
    }
    
    // MARK: - Record a Scan Result
    
    /// Call this after every successful meal scan to collect training data.
    /// - Parameters:
    ///   - image: The original photo the user took
    ///   - items: The parsed food items returned by AI (or edited by user)
    ///   - wasEdited: Whether the user corrected the AI's output (better labels)
    func record(image: UIImage, items: [ParsedItem], wasEdited: Bool = false) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            // Compress image to save storage (224x224 is standard for image classifiers)
            guard let imageData = self.prepareTrainingImage(image) else {
                print("⚠️ MealDataCollector: Failed to compress image")
                return
            }
            
            let sampleId = UUID().uuidString
            let imageFileName = "\(sampleId).jpg"
            let imagePath = self.imagesDirectory.appendingPathComponent(imageFileName)
            
            // Save image to disk
            do {
                try imageData.write(to: imagePath)
            } catch {
                print("⚠️ MealDataCollector: Failed to save image: \(error)")
                return
            }
            
            // Create labeled samples (one per detected food item)
            var manifest = self.loadManifest()
            
            for item in items {
                let sample = FoodSample(
                    id: "\(sampleId)_\(item.name.hashValue)",
                    timestamp: Date(),
                    foodName: item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                    category: self.inferCategory(for: item.name),
                    calories: item.calories ?? 0,
                    protein: item.protein ?? 0,
                    carbs: item.carbs ?? 0,
                    fat: item.fat ?? 0,
                    sugar: item.sugar ?? 0,
                    portionSize: item.portionSize,
                    confidence: item.confidence,
                    imageFileName: imageFileName,
                    wasUserEdited: wasEdited
                )
                
                manifest.samples.append(sample)
                manifest.foodFrequency[sample.foodName, default: 0] += 1
            }
            
            manifest.totalSamples = manifest.samples.count
            manifest.uniqueFoods = manifest.foodFrequency.count
            manifest.lastUpdated = Date()
            
            self.saveManifest(manifest)
            
            #if DEBUG
            print("📸 MealDataCollector: Recorded \(items.count) items (\(manifest.totalSamples) total samples, \(manifest.uniqueFoods) unique foods)")
            #endif
        }
    }
    
    /// Record from editable items (when user corrects the AI output — these are gold-standard labels).
    func recordEdited(image: UIImage, items: [EditableParsedItem]) {
        let parsedItems = items.map { item in
            ParsedItem(
                name: item.name,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                sugar: item.sugar,
                portionSize: item.qtyText.isEmpty ? nil : item.qtyText,
                confidence: 1.0  // User-verified = maximum confidence
            )
        }
        record(image: image, items: parsedItems, wasEdited: true)
    }
    
    // MARK: - Image Preparation
    
    /// Resize and compress image for training (224x224 JPEG, ~30-50KB each).
    private func prepareTrainingImage(_ image: UIImage) -> Data? {
        let targetSize = CGSize(width: 224, height: 224)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        // Center-crop to square first
        let sourceSize = image.size
        let shortSide = min(sourceSize.width, sourceSize.height)
        let cropRect = CGRect(
            x: (sourceSize.width - shortSide) / 2,
            y: (sourceSize.height - shortSide) / 2,
            width: shortSide,
            height: shortSide
        )
        
        if let cgImage = image.cgImage?.cropping(to: cropRect) {
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: targetSize))
        } else {
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        return resized?.jpegData(compressionQuality: 0.85)
    }
    
    // MARK: - Manifest Management
    
    private func loadManifest() -> DatasetManifest {
        guard let data = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder.iso8601.decode(DatasetManifest.self, from: data) else {
            return DatasetManifest(
                version: 1,
                totalSamples: 0,
                uniqueFoods: 0,
                lastUpdated: Date(),
                foodFrequency: [:],
                samples: []
            )
        }
        return manifest
    }
    
    private func saveManifest(_ manifest: DatasetManifest) {
        if let data = try? JSONEncoder.iso8601.encode(manifest) {
            try? data.write(to: manifestURL)
        }
    }
    
    // MARK: - Category Inference
    
    private func inferCategory(for foodName: String) -> String? {
        if let info = LocalNutritionDatabase.shared.lookup(foodName) {
            return info.category
        }
        return nil
    }
    
    // MARK: - Dataset Statistics (for dashboard)
    
    /// Get current dataset stats.
    var stats: DatasetStats {
        let manifest = loadManifest()
        let userEditedCount = manifest.samples.filter { $0.wasUserEdited }.count
        let diskUsage = calculateDiskUsage()
        
        return DatasetStats(
            totalSamples: manifest.totalSamples,
            uniqueFoods: manifest.uniqueFoods,
            userEditedSamples: userEditedCount,
            topFoods: Array(manifest.foodFrequency.sorted { $0.value > $1.value }.prefix(20)),
            diskUsageMB: Double(diskUsage) / (1024 * 1024),
            lastUpdated: manifest.lastUpdated,
            isReadyForTraining: manifest.totalSamples >= 50 && manifest.uniqueFoods >= 10
        )
    }
    
    struct DatasetStats {
        let totalSamples: Int
        let uniqueFoods: Int
        let userEditedSamples: Int
        let topFoods: [(key: String, value: Int)]
        let diskUsageMB: Double
        let lastUpdated: Date
        let isReadyForTraining: Bool  // Need at least 50 samples & 10 unique foods
    }
    
    /// All known food labels in the collected dataset.
    var knownFoodLabels: Set<String> {
        Set(loadManifest().foodFrequency.keys)
    }
    
    /// Check if we have enough data for a specific food to classify it locally.
    func sampleCount(for foodName: String) -> Int {
        loadManifest().foodFrequency[foodName.lowercased()] ?? 0
    }
    
    // MARK: - Disk Usage
    
    private func calculateDiskUsage() -> Int64 {
        var totalSize: Int64 = 0
        if let enumerator = fileManager.enumerator(at: baseDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            while let url = enumerator.nextObject() as? URL {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        return totalSize
    }
    
    // MARK: - Cleanup
    
    /// Clear all collected training data.
    func clearAllData() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.fileManager.removeItem(at: self.baseDirectory)
            self.setupDirectories()
            print("🗑️ MealDataCollector: All training data cleared")
        }
    }
    
    /// Remove samples older than N days to manage storage.
    func pruneOldSamples(olderThanDays: Int = 90) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var manifest = self.loadManifest()
            let cutoff = Calendar.current.date(byAdding: .day, value: -olderThanDays, to: Date()) ?? Date()
            
            let oldSamples = manifest.samples.filter { $0.timestamp < cutoff }
            manifest.samples.removeAll { $0.timestamp < cutoff }
            
            // Delete orphaned images
            let remainingImages = Set(manifest.samples.map { $0.imageFileName })
            for sample in oldSamples {
                if !remainingImages.contains(sample.imageFileName) {
                    let imagePath = self.imagesDirectory.appendingPathComponent(sample.imageFileName)
                    try? self.fileManager.removeItem(at: imagePath)
                }
            }
            
            // Rebuild frequency map
            manifest.foodFrequency = [:]
            for sample in manifest.samples {
                manifest.foodFrequency[sample.foodName, default: 0] += 1
            }
            manifest.totalSamples = manifest.samples.count
            manifest.uniqueFoods = manifest.foodFrequency.count
            manifest.lastUpdated = Date()
            
            self.saveManifest(manifest)
            print("🧹 Pruned \(oldSamples.count) old samples")
        }
    }
}

// MARK: - JSON Coder helpers
private extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

private extension JSONEncoder {
    static let iso8601: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
