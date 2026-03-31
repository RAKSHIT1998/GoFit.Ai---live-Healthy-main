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

    // Replace with your OpenAI API key
    private let apiKey = "sk-..."

    func analyzeFood(image: UIImage) async throws -> [OpenAIFoodNutrition] {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "OpenAI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
        }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Encode image as base64
        let base64Image = imageData.base64EncodedString()
        let prompt = "Analyze the following food photo and return a JSON array of objects with fields: food, calories, protein, carbs, fat, details."
        let messages: [[String: Any]] = [
            ["role": "system", "content": "You are a nutrition expert."],
            ["role": "user", "content": [
                ["type": "text", "text": prompt],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
            ]]
        ]
        let body: [String: Any] = [
            "model": "gpt-4-vision-preview",
            "messages": messages,
            "max_tokens": 600
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let httpResponse = resp as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            let errStr = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errStr])
        }
        // Parse OpenAI response
        struct OpenAIResponse: Codable {
            struct Choice: Codable {
                struct Message: Codable {
                    let content: String?
                }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw NSError(domain: "OpenAI", code: 0, userInfo: [NSLocalizedDescriptionKey: "No content in OpenAI response"])
        }
        // Extract JSON array from content
        guard let jsonStart = content.firstIndex(of: "[") else {
            throw NSError(domain: "OpenAI", code: 0, userInfo: [NSLocalizedDescriptionKey: "No JSON array in response"])
        }
        let jsonString = String(content[jsonStart...])
        let nutrition = try JSONDecoder().decode([OpenAIFoodNutrition].self, from: Data(jsonString.utf8))
        return nutrition
    }
}
