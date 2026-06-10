import SwiftUI

// MARK: - API

private struct CalorieShockResponse: Decodable {
    struct ActivityShock: Decodable {
        let activity: String
        let emoji: String
        let minutes: Int
        let formattedTime: String
    }
    let mealName: String?
    let calories: Int
    let shocks: [ActivityShock]
    let shareText: String
}

// MARK: - Compact Banner shown after meal scan

struct CalorieShockBanner: View {
    let mealName: String
    let calories: Int
    @State private var shock: CalorieShockResponse?
    @State private var showFull = false
    @State private var visible = false

    var body: some View {
        if visible, let s = shock {
            Button { showFull = true } label: {
                HStack(spacing: 10) {
                    Text(s.shocks.first?.emoji ?? "🏃")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Calorie Shock 😱")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                        Text("\(mealName) = \(s.shocks.first?.formattedTime ?? "") of \(s.shocks.first?.activity ?? "")")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(12)
                .background(
                    LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .sheet(isPresented: $showFull) {
                CalorieShockDetailView(shock: s)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    func appear() {
        Task {
            await fetchShock()
            withAnimation(.spring(response: 0.4)) { visible = true }
        }
    }

    private func fetchShock() async {
        guard calories > 0,
              let token = AuthService.shared.readToken()?.accessToken,
              let url = URL(string: "\(APIConfig.baseURL)/viral/calorie-shock") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["mealName": mealName, "calories": calories])
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }
        shock = try? JSONDecoder().decode(CalorieShockResponse.self, from: data)
    }
}

// MARK: - Full Detail Sheet

struct CalorieShockDetailView: View {
    let shock: CalorieShockResponse
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    activitiesGrid
                    shareSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Calorie Shock 😱")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [shock.shareText])
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("😱")
                .font(.system(size: 56))
            Text("\(shock.mealName ?? "That meal")")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            HStack(spacing: 4) {
                Text("\(shock.calories)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.orange)
                Text("cal")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .offset(y: 10)
            }
            Text("Here's what you'd need to do to burn it off 👇")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var activitiesGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(shock.shocks, id: \.activity) { s in
                activityTile(s)
            }
        }
    }

    private func activityTile(_ s: CalorieShockResponse.ActivityShock) -> some View {
        VStack(spacing: 8) {
            Text(s.emoji).font(.system(size: 32))
            Text(s.formattedTime)
                .font(.headline.bold())
                .foregroundStyle(.primary)
            Text(s.activity)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var shareSection: some View {
        VStack(spacing: 10) {
            Button {
                showShareSheet = true
                Task { await trackShare() }
            } label: {
                Label("Share the Shock 😱", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            Text("Your friends need to see this 😭")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func trackShare() async {
        guard let token = AuthService.shared.readToken()?.accessToken,
              let url = URL(string: "\(APIConfig.baseURL)/viral/track-share") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["type": "calorie_shock"])
        _ = try? await URLSession.shared.data(for: request)
        ReferralManager.shared.recordShare()
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
