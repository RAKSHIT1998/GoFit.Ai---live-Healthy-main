import SwiftUI

struct Exercise3DLibraryView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "cube.transparent")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                Text("3D Exercise Library")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Browse animated 3D demonstrations for every exercise. Tap an exercise to view form tips, muscle groups, and a 3D/AR model.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Spacer()
                // Placeholder for exercise list/grid
                Text("Coming soon: Search, filter, and view 3D/AR exercise demos!")
                    .font(.headline)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding()
            .navigationTitle("3D Library")
        }
    }
}

#Preview {
    Exercise3DLibraryView()
}
