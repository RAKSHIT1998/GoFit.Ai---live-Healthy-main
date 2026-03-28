import Foundation

struct AnalyticsData: Codable {
    let period: String // e.g. "weekly"
    let date: Date
    let nutrition: NutritionAnalytics
    let fitness: FitnessAnalytics
    let progress: ProgressAnalytics?
    let goals: GoalsAnalytics?
    let insights: [String]?
}

struct NutritionAnalytics: Codable {
    let totalCalories: Double?
    let averageCalories: Double?
    let totalProtein: Double?
    let averageProtein: Double?
    let totalCarbs: Double?
    let averageCarbs: Double?
    let totalFat: Double?
    let averageFat: Double?
    let totalSugar: Double?
    let averageSugar: Double?
    let macroDistribution: MacroDistribution?
    let mealCount: Int?
    let consistencyScore: Double?
}

struct MacroDistribution: Codable {
    let protein: Double?
    let carbs: Double?
    let fat: Double?
}

struct FitnessAnalytics: Codable {
    let totalWorkouts: Int?
    let totalDuration: Double?
    let totalCaloriesBurned: Double?
    let averageWorkoutDuration: Double?
    let workoutTypes: [WorkoutTypeAnalytics]?
    let consistencyScore: Double?
}

struct WorkoutTypeAnalytics: Codable {
    let type: String
    let count: Int
    let totalDuration: Double
}

struct ProgressAnalytics: Codable {
    let weightChange: Double?
    let bodyFatChange: Double?
    let measurementChanges: MeasurementChanges?
}

struct MeasurementChanges: Codable {
    let chest: Double?
    let waist: Double?
    let hips: Double?
    let arms: Double?
}

struct GoalsAnalytics: Codable {
    let caloriesGoal: Double?
    let caloriesAchieved: Double?
    let proteinGoal: Double?
    let proteinAchieved: Double?
    let workoutGoal: Double?
    let workoutAchieved: Double?
}
