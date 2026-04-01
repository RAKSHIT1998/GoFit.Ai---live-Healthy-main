import Foundation

struct ServerMealResponse: Codable {
    var mealId: String?
    var parsedItems: [ServerMealItem]?
    var recommendations: String?
}

struct ServerMealItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let calories: Double?
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let details: String?
}
