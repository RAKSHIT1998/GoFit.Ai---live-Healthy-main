import Foundation
import UIKit

// MARK: - Meal Training Exporter
/// Exports collected food image + label data in Apple Create ML compatible format.
///
/// Create ML expects this folder structure for image classification:
/// ```
/// ExportedTrainingData/
/// ├── Apple/
/// │   ├── img_001.jpg
/// │   └── img_002.jpg
/// ├── Banana/
/// │   ├── img_003.jpg
/// │   └── img_004.jpg
/// └── Rice/
///     └── img_005.jpg
/// ```
///
/// To retrain:
/// 1. Export data using this class
/// 2. Open Create ML in Xcode (Xcode → Open Developer Tool → Create ML)
/// 3. Create "Image Classifier" project
/// 4. Drag the exported folder as training data
/// 5. Train → produces GoFitFoodClassifier.mlmodel
/// 6. Add the .mlmodel to the app bundle
/// 7. LocalFoodClassifier Layer 1 will automatically use it!
class MealTrainingExporter {
    static let shared = MealTrainingExporter()
    
    private let dataCollector = MealDataCollector.shared
    
    struct ExportResult {
        let exportPath: URL
        let totalImages: Int
        let totalCategories: Int
        let skippedSamples: Int
    }
    
    // MARK: - Export for Create ML
    
    /// Export all collected training data in Create ML Image Classifier format.
    /// - Returns: ExportResult with path and stats
    func exportForCreateML() async throws -> ExportResult {
        let stats = dataCollector.stats
        guard stats.totalSamples > 0 else {
            throw ExportError.noTrainingData
        }
        
        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportDir = documentsDir.appendingPathComponent("GoFitTrainingExport", isDirectory: true)
        
        // Clean previous export
        if fileManager.fileExists(atPath: exportDir.path) {
            try fileManager.removeItem(at: exportDir)
        }
        try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)
        
        // Read manifest
        let dataDir = documentsDir.appendingPathComponent("MealTrainingData", isDirectory: true)
        let manifestURL = dataDir.appendingPathComponent("manifest.json")
        
        guard let manifestData = try? Data(contentsOf: manifestURL),
              let manifest = try? JSONDecoder().decode(MealDataCollector.DatasetManifest.self, from: manifestData) else {
            throw ExportError.corruptManifest
        }
        
        let imagesDir = dataDir.appendingPathComponent("images", isDirectory: true)
        var totalImages = 0
        var skipped = 0
        var categories = Set<String>()
        
        for sample in manifest.samples {
            // Create category folder (sanitize name for filesystem)
            let categoryName = sanitizeForFilesystem(sample.foodName)
            let categoryDir = exportDir.appendingPathComponent(categoryName, isDirectory: true)
            
            if !fileManager.fileExists(atPath: categoryDir.path) {
                try fileManager.createDirectory(at: categoryDir, withIntermediateDirectories: true)
            }
            
            // Copy image to category folder
            let sourceImage = imagesDir.appendingPathComponent(sample.imageFileName)
            guard fileManager.fileExists(atPath: sourceImage.path) else {
                skipped += 1
                continue
            }
            
            let destImage = categoryDir.appendingPathComponent("\(sample.id.prefix(8)).jpg")
            try fileManager.copyItem(at: sourceImage, to: destImage)
            
            totalImages += 1
            categories.insert(categoryName)
        }
        
        // Also export a CSV with detailed nutrition data for regression training
        try exportNutritionCSV(manifest: manifest, to: exportDir)
        
        #if DEBUG
        print("📦 Training data exported to: \(exportDir.path)")
        print("   📸 \(totalImages) images in \(categories.count) categories")
        #endif
        
        return ExportResult(
            exportPath: exportDir,
            totalImages: totalImages,
            totalCategories: categories.count,
            skippedSamples: skipped
        )
    }
    
    // MARK: - Export Nutrition CSV
    
    /// Exports a CSV with detailed nutrition info for each sample.
    /// Useful for training nutrition estimation models (regression).
    private func exportNutritionCSV(manifest: MealDataCollector.DatasetManifest, to dir: URL) throws {
        var csv = "image_file,food_name,category,calories,protein,carbs,fat,sugar,portion_size,confidence,user_edited\n"
        
        for sample in manifest.samples {
            let row = [
                sample.imageFileName,
                sample.foodName.replacingOccurrences(of: ",", with: " "),
                (sample.category ?? "unknown").replacingOccurrences(of: ",", with: " "),
                String(format: "%.1f", sample.calories),
                String(format: "%.1f", sample.protein),
                String(format: "%.1f", sample.carbs),
                String(format: "%.1f", sample.fat),
                String(format: "%.1f", sample.sugar),
                (sample.portionSize ?? "1 serving").replacingOccurrences(of: ",", with: " "),
                String(format: "%.2f", sample.confidence ?? 0.0),
                sample.wasUserEdited ? "true" : "false"
            ].joined(separator: ",")
            csv += row + "\n"
        }
        
        let csvURL = dir.appendingPathComponent("nutrition_data.csv")
        try csv.write(to: csvURL, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Export for Share/Transfer
    
    /// Create a compressed archive of training data for transfer to Mac for training.
    func createShareableArchive() async throws -> URL {
        let result = try await exportForCreateML()
        
        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let archivePath = documentsDir.appendingPathComponent("GoFit_TrainingData.zip")
        
        // Remove old archive
        if fileManager.fileExists(atPath: archivePath.path) {
            try fileManager.removeItem(at: archivePath)
        }
        
        // Create zip using Coordinator pattern
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var archiveURL: URL?
        
        coordinator.coordinate(readingItemAt: result.exportPath,
                             options: .forUploading,
                             error: &coordinatorError) { zipURL in
            do {
                try FileManager.default.copyItem(at: zipURL, to: archivePath)
                archiveURL = archivePath
            } catch {
                #if DEBUG
                print("❌ Failed to create archive: \(error)")
                #endif
            }
        }
        
        if let error = coordinatorError {
            throw error
        }
        
        return archiveURL ?? archivePath
    }
    
    // MARK: - Helpers
    
    private func sanitizeForFilesystem(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-_ "))
        return name
            .components(separatedBy: allowed.inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
            .prefix(50)
            .lowercased()
            .isEmpty ? "unknown" : String(name
                .components(separatedBy: allowed.inverted)
                .joined()
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: " ", with: "_")
                .prefix(50)
                .lowercased())
    }
    
    enum ExportError: LocalizedError {
        case noTrainingData
        case corruptManifest
        case exportFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .noTrainingData:
                return "No training data collected yet. Scan some meals first!"
            case .corruptManifest:
                return "Training data manifest is corrupted. Try scanning a new meal."
            case .exportFailed(let reason):
                return "Export failed: \(reason)"
            }
        }
    }
}
