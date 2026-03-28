import Foundation

struct Exercise3DModel: Identifiable, Codable {
    let id: String
    let name: String
    let muscleGroups: [String]
    let difficulty: String
    let demoImageUrl: String?
    let gifUrl: String?
    let videoUrl: String?
    let modelUrl: String? // USDZ or GLB for AR/3D
    let formTips: [String]?
}

extension Exercise3DModel {
    static let sample: [Exercise3DModel] = [
        Exercise3DModel(
            id: "squat",
            name: "Squat",
            muscleGroups: ["Legs", "Glutes", "Core"],
            difficulty: "Beginner",
            demoImageUrl: nil,
            gifUrl: "https://media.giphy.com/media/3o7TKMt1VVNkHV2PaE/giphy.gif",
            videoUrl: nil,
            modelUrl: nil,
            formTips: ["Keep your chest up.", "Push through your heels.", "Don't let knees cave in."]
        ),
        Exercise3DModel(
            id: "pushup",
            name: "Push-Up",
            muscleGroups: ["Chest", "Triceps", "Shoulders", "Core"],
            difficulty: "Beginner",
            demoImageUrl: nil,
            gifUrl: "https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif",
            videoUrl: nil,
            modelUrl: nil,
            formTips: ["Keep your body in a straight line.", "Lower until elbows are at 90°.", "Don't flare elbows out."]
        )
    ]
}
