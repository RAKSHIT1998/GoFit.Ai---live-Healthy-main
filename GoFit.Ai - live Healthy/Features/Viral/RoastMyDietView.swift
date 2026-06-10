import SwiftUI

// MARK: - API Response

private struct RoastResponse: Decodable {
    let roast: String
    let score: Int
    let badge: String
    let totalCaloriesThisWeek: Int?
    let avgDailyCalories: Int?
    let uniqueFoodsLogged: Int?
    let shareText: String
}

// MARK: - View Model

@MainActor
private class RoastViewModel: ObservableObject {
    @Published var roast: RoastResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchRoast() async {
        guard let token = AuthService.shared.readToken()?.accessToken,
              let url = URL(string: "\(APIConfig.baseURL)/viral/roast-diet") else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                errorMessage = "Couldn't load your roast. Try again!"
                return
            }
            roast = try JSONDecoder().decode(RoastResponse.self, from: data)
        } catch {
            errorMessage = "Network error. Make sure you're connected."
        }
    }
}

// MARK: - Main View

struct RoastMyDietView: View {
    @StateObject private var vm = RoastViewModel()
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var cardScale: CGFloat = 0.8
    @State private var cardOpacity: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                if vm.isLoading {
                    loadingSection
                } else if let roast = vm.roast {
                    roastCard(roast)
                    statsRow(roast)
                    shareButton(roast)
                } else {
                    ctaSection
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Roast My Diet 🔥")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("🔥")
                .font(.system(size: 60))
            Text("Get Roasted")
                .font(.title.bold())
            Text("Let our AI brutally (but lovingly) review your diet this week.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Preparing your roast...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var ctaSection: some View {
        VStack(spacing: 20) {
            if let err = vm.errorMessage {
                Text(err)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    await vm.fetchRoast()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        cardScale = 1.0
                        cardOpacity = 1.0
                    }
                }
            } label: {
                Label("Roast My Diet 🔥", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Text("⚠️ This will hurt a little.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func roastCard(_ roast: RoastResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(roast.badge)
                        .font(.headline)
                    Text("Your Diet Badge")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                scoreRing(score: roast.score)
            }

            Divider()

            Text(roast.roast)
                .font(.body)
                .lineSpacing(4)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .scaleEffect(cardScale)
        .opacity(cardOpacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
        }
    }

    private func scoreRing(score: Int) -> some View {
        ZStack {
            Circle()
                .stroke(Color(.systemFill), lineWidth: 6)
                .frame(width: 60, height: 60)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    score > 60 ? Color.green : score > 30 ? Color.orange : Color.red,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 60, height: 60)
            Text("\(score)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
    }

    @ViewBuilder
    private func statsRow(_ roast: RoastResponse) -> some View {
        HStack(spacing: 12) {
            if let cal = roast.totalCaloriesThisWeek {
                statPill(label: "Total Cal", value: "\(cal)", emoji: "🔥")
            }
            if let avg = roast.avgDailyCalories {
                statPill(label: "Avg/Day", value: "\(avg)", emoji: "📊")
            }
            if let foods = roast.uniqueFoodsLogged {
                statPill(label: "Foods", value: "\(foods)", emoji: "🍽️")
            }
        }
    }

    private func statPill(label: String, value: String, emoji: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.title3)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func shareButton(_ roast: RoastResponse) -> some View {
        VStack(spacing: 12) {
            Button {
                shareItems = [roast.shareText]
                showShareSheet = true
                Task {
                    await trackShare()
                }
            } label: {
                Label("Share My Roast 😂", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button {
                cardScale = 0.8
                cardOpacity = 0
                Task {
                    await vm.fetchRoast()
                }
            } label: {
                Label("Get Re-Roasted", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func trackShare() async {
        guard let token = AuthService.shared.readToken()?.accessToken,
              let url = URL(string: "\(APIConfig.baseURL)/viral/track-share") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["type": "roast"])
        _ = try? await URLSession.shared.data(for: request)
        ReferralManager.shared.recordShare()
    }
}

// MARK: - UIKit Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        RoastMyDietView()
    }
}
