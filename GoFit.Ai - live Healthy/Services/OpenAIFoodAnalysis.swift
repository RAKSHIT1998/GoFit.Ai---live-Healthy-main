import Foundation
import UIKit

struct OpenAIFoodNutrition: Codable {
    let food: String
    let calories: Int?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let details: String?
}

final class OpenAIFoodAnalysisService {
    static let shared = OpenAIFoodAnalysisService()
    private init() {}

    func analyzeFood(image: UIImage, userId: String? = nil) async throws -> [OpenAIFoodNutrition] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "MealAnalysis", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        let response = try await NetworkManager.shared.uploadMealImage(
            data: imageData,
            filename: "meal.jpg",
            userId: userId
        )

        let items = response.parsedItems ?? []
        guard !items.isEmpty else {
            throw NSError(domain: "MealAnalysis", code: 0, userInfo: [NSLocalizedDescriptionKey: "AI analysis returned no food items. Please try again with a clearer photo."])
        }

        return items.map { item in
            OpenAIFoodNutrition(
                food: item.name,
                calories: item.calories.map { Int($0.rounded()) },
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                details: item.portionSize
            )
        }
    }
}
