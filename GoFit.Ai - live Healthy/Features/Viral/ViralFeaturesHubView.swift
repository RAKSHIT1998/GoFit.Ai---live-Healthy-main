import SwiftUI

/// Entry point that groups all viral / sharing features in one place.
/// Add a NavigationLink to this from Settings, the Home tab, or the SocialHub.
struct ViralFeaturesHubView: View {
    @ObservedObject private var referral = ReferralManager.shared
    @ObservedObject private var streak  = StreakManager.shared
    @State private var showShareSheet   = false
    @State private var shareItems: [Any] = []

    var body: some View {
        List {
            // ── Share Your Stats ──────────────────────────────
            Section("Share Your Stats") {
                NavigationLink(destination: RoastMyDietView()) {
                    featureRow(
                        emoji: "🔥",
                        title: "Roast My Diet",
                        subtitle: "AI brutally reviews your week in food",
                        accentColor: .orange
                    )
                }

                NavigationLink(destination: WeeklyReportView()) {
                    featureRow(
                        emoji: "📊",
                        title: "Weekly Report",
                        subtitle: "Spotify Wrapped-style weekly summary",
                        accentColor: .blue
                    )
                }

                Button {
                    let text = ShareService().generateShareText()
                    shareItems = [text]
                    showShareSheet = true
                    Task { await trackShare(type: "progress") }
                } label: {
                    featureRow(
                        emoji: "💪",
                        title: "Share My Progress",
                        subtitle: "Tell the world how far you've come",
                        accentColor: .green
                    )
                }
                .buttonStyle(.plain)
            }

            // ── Invite Friends ────────────────────────────────
            Section("Invite & Earn") {
                NavigationLink(destination: ReferralDashboardView()) {
                    featureRow(
                        emoji: referral.currentTier.emoji,
                        title: "Referral Dashboard",
                        subtitle: "\(referral.totalReferrals) friends invited · \(referral.currentTier.name) tier",
                        accentColor: referral.currentTier.color
                    )
                }

                Button {
                    let msg = referral.getInviteMessage(userName: "You")
                    shareItems = [msg]
                    showShareSheet = true
                    referral.recordShare()
                } label: {
                    featureRow(
                        emoji: "🎁",
                        title: "Invite a Friend",
                        subtitle: "Code: \(referral.referralCode.isEmpty ? "Generate in Referral Dashboard" : referral.referralCode)",
                        accentColor: .purple
                    )
                }
                .buttonStyle(.plain)
            }

            // ── Your Streak ───────────────────────────────────
            Section("Your Streak") {
                HStack(spacing: 16) {
                    Text(streak.streakEmoji)
                        .font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(streak.currentStreak)-Day Streak")
                            .font(.headline)
                        Text("Level \(streak.level) · \(streak.levelTitle) · \(streak.totalPoints) pts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                Button {
                    let text = "I'm on a \(streak.currentStreak)-day streak on GoFit.AI! 🔥 Level \(streak.level) · \(streak.totalPoints) pts. Join me! #GoFitAi #StreakChallenge"
                    shareItems = [text]
                    showShareSheet = true
                    Task { await trackShare(type: "streak") }
                } label: {
                    featureRow(
                        emoji: "🔥",
                        title: "Share My Streak",
                        subtitle: "Challenge your friends to beat it",
                        accentColor: .red
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Viral Features")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
    }

    private func featureRow(emoji: String, title: String, subtitle: String, accentColor: Color) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text(emoji).font(.title3)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func trackShare(type: String) async {
        guard let token = AuthService.shared.readToken()?.accessToken,
              let url = URL(string: "\(APIConfig.baseURL)/viral/track-share") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["type": type])
        _ = try? await URLSession.shared.data(for: request)
        referral.recordShare()
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
    NavigationStack { ViralFeaturesHubView() }
}
