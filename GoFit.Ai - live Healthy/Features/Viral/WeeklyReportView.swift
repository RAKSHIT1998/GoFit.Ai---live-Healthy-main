import SwiftUI

// MARK: - API Response

private struct WeeklyReport: Decodable {
    let week: String
    let mealsLogged: Int
    let totalCalories: Int?
    let avgDailyCalories: Int?
    let totalProtein: Int?
    let totalCarbs: Int?
    let totalFat: Int?
    let totalSugar: Int?
    let bestDay: String?
    let worstDay: String?
    let topFood: String?
    let weeklyXP: Int?
    let shareText: String
    let message: String?
}

// MARK: - ViewModel

@MainActor
private class WeeklyReportViewModel: ObservableObject {
    @Published var report: WeeklyReport?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        guard let token = AuthService.shared.readToken()?.accessToken,
              let url = URL(string: "\(APIConfig.baseURL)/viral/weekly-report") else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                errorMessage = "Couldn't load your report."
                return
            }
            report = try JSONDecoder().decode(WeeklyReport.self, from: data)
        } catch {
            errorMessage = "Network error."
        }
    }
}

// MARK: - View

struct WeeklyReportView: View {
    @StateObject private var vm = WeeklyReportViewModel()
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var animateCards = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if vm.isLoading {
                    ProgressView("Crunching your week...").padding(40)
                } else if let report = vm.report {
                    weekHeader(report)
                    macroGrid(report)
                    highlightCards(report)
                    shareCard(report)
                } else if let err = vm.errorMessage {
                    Text(err).foregroundStyle(.red).padding()
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("My Week in Food 📊")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.load() }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }

    // MARK: - Sections

    private func weekHeader(_ r: WeeklyReport) -> some View {
        VStack(spacing: 6) {
            Text("📊")
                .font(.system(size: 48))
                .scaleEffect(animateCards ? 1.0 : 0.5)
                .animation(.spring(response: 0.5), value: animateCards)
            Text("Week of \(formatWeek(r.week))")
                .font(.title2.bold())
            Text("\(r.mealsLogged) meals logged")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear { animateCards = true }
    }

    @ViewBuilder
    private func macroGrid(_ r: WeeklyReport) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let cal = r.totalCalories {
                macroTile("Total Calories", value: "\(cal)", unit: "kcal", color: .orange, emoji: "🔥")
            }
            if let avg = r.avgDailyCalories {
                macroTile("Daily Average", value: "\(avg)", unit: "kcal/day", color: .blue, emoji: "📈")
            }
            if let protein = r.totalProtein {
                macroTile("Protein", value: "\(protein)g", unit: "this week", color: .green, emoji: "💪")
            }
            if let sugar = r.totalSugar {
                macroTile("Sugar", value: "\(sugar)g", unit: "total", color: .pink, emoji: "🍬")
            }
        }
    }

    private func macroTile(_ title: String, value: String, unit: String, color: Color, emoji: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emoji).font(.title2)
            Text(value).font(.title2.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(unit).font(.caption2).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func highlightCards(_ r: WeeklyReport) -> some View {
        VStack(spacing: 12) {
            if let best = r.bestDay {
                highlightRow(emoji: "⭐️", title: "Best Day", value: best, color: .green)
            }
            if let worst = r.worstDay {
                highlightRow(emoji: "😅", title: "Cheat Day", value: worst, color: .orange)
            }
            if let food = r.topFood {
                highlightRow(emoji: "🏆", title: "Most Eaten", value: food, color: .purple)
            }
            if let xp = r.weeklyXP, xp > 0 {
                highlightRow(emoji: "⚡️", title: "XP Earned", value: "\(xp) pts", color: .yellow)
            }
        }
    }

    private func highlightRow(emoji: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Text(emoji).font(.title2).frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.bold())
            }
            Spacer()
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.2))
                .frame(width: 4, height: 36)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func shareCard(_ r: WeeklyReport) -> some View {
        VStack(spacing: 12) {
            Button {
                shareItems = [r.shareText]
                showShareSheet = true
                Task { await trackShare() }
            } label: {
                Label("Share My Week 📊", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Text("Share as an Instagram caption, Story, or WhatsApp status")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helpers

    private func formatWeek(_ iso: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: iso) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        return iso
    }

    private func trackShare() async {
        guard let token = AuthService.shared.readToken()?.accessToken,
              let url = URL(string: "\(APIConfig.baseURL)/viral/track-share") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["type": "weekly_report"])
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

#Preview {
    NavigationStack { WeeklyReportView() }
}
