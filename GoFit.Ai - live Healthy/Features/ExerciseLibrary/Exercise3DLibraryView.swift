import SwiftUI

struct Exercise3DLibraryView: View {
    @State private var selectedExercise: Exercise3DModel? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "cube.transparent")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.blue)
                    Text("3D Exercise Library")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                Text("Browse animated 3D demonstrations for every exercise. Tap an exercise to view form tips, muscle groups, and a 3D/AR model.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(Exercise3DModel.sample) { exercise in
                            Button {
                                selectedExercise = exercise
                            } label: {
                                HStack(spacing: 16) {
                                    if let gifUrl = exercise.gifUrl, let url = URL(string: gifUrl) {
                                        AsyncImage(url: url) { image in
                                            image.resizable().scaledToFit()
                                        } placeholder: {
                                            ProgressView()
                                        }
                                        .frame(width: 64, height: 64)
                                        .cornerRadius(12)
                                    } else {
                                        Image(systemName: "figure.strengthtraining.traditional")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 64, height: 64)
                                            .foregroundColor(.gray)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exercise.name)
                                            .font(.headline)
                                        Text(exercise.muscleGroups.joined(separator: ", "))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text(exercise.difficulty)
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(14)
                            }
                        }
                    }
                    .padding(.vertical)
                }
            }
            .padding()
            .navigationTitle("3D Library")
            .sheet(item: $selectedExercise) { exercise in
                Exercise3DDetailView(exercise: exercise)
            }
        }
    }
}


struct Exercise3DDetailView: View {
    let exercise: Exercise3DModel

    var body: some View {
        VStack(spacing: 20) {
            if let gifUrl = exercise.gifUrl, let url = URL(string: gifUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 180)
                .cornerRadius(16)
            }
            Text(exercise.name)
                .font(.title)
                .fontWeight(.bold)
            Text("Muscle Groups: " + exercise.muscleGroups.joined(separator: ", "))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Difficulty: " + exercise.difficulty)
                .font(.subheadline)
                .foregroundColor(.blue)
            if let formTips = exercise.formTips, !formTips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Form Tips:")
                        .font(.headline)
                    ForEach(formTips, id: \.self) { tip in
                        Text("• " + tip)
                            .font(.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
        }
        .padding()
    }
}
