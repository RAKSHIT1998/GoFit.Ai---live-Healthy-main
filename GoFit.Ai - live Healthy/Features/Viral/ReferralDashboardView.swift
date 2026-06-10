import SwiftUI

struct ReferralDashboardView: View {
    @ObservedObject private var manager = ReferralManager.shared
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var referralCodeInput = ""
    @State private var showClaimAlert = false
    @State private var claimResult: String?
    @State private var showCopied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                tierCard
                codeSection
                progressBar
                if !manager.referralCode.isEmpty {
                    inviteButtons
                }
                if !manager.referralHistory.isEmpty {
                    historySection
                }
                if !manager.isReferralClaimed {
                    claimSection
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Referral Program")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .alert("Enter Referral Code", isPresented: $showClaimAlert) {
            TextField("e.g. GOFITRAK42A", text: $referralCodeInput)
                .textInputAutocapitalization(.characters)
            Button("Apply") { applyCode() }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let result = claimResult { Text(result) }
        }
        .overlay(alignment: .top) {
            if showCopied {
                Text("Code copied! ✓")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Color.green)
                    .clipShape(Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task {
            await manager.syncFromBackend()
        }
    }

    // MARK: - Sections

    private var tierCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(manager.currentTier.emoji + " " + manager.currentTier.name)
                        .font(.title2.bold())
                    Text(manager.currentTier.perkDescription)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(manager.totalReferrals)")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("friends invited")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }

            HStack {
                Text("\(manager.totalXPEarned) XP earned")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                if let next = manager.currentTier.nextTier {
                    Text("\(manager.referralsToNextTier) more to \(next.name) \(next.emoji)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                } else {
                    Text("Max tier reached 👑")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: manager.currentTier.gradientColors,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var codeSection: some View {
        VStack(spacing: 10) {
            Text("Your Referral Code")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if manager.referralCode.isEmpty {
                Button("Generate My Code") {
                    if let user = AuthService.shared.currentUser {
                        _ = manager.generateCode(for: user.id ?? "", name: user.name ?? "GoFit")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } else {
                HStack {
                    Text(manager.referralCode)
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .tracking(3)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = manager.referralCode
                        withAnimation { showCopied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showCopied = false }
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        if let next = manager.currentTier.nextTier {
            VStack(spacing: 6) {
                HStack {
                    Text(manager.currentTier.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(next.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemFill))
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: manager.currentTier.gradientColors,
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * manager.progressToNextTier, height: 8)
                            .animation(.easeOut(duration: 0.8), value: manager.progressToNextTier)
                    }
                }
                .frame(height: 8)
                Text("\(manager.totalReferrals) / \(next.requiredReferrals) friends")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inviteButtons: some View {
        VStack(spacing: 10) {
            Button {
                let msg = manager.getInviteMessage(userName: AuthService.shared.currentUser?.name ?? "A friend")
                shareItems = [msg]
                showShareSheet = true
                manager.recordShare()
            } label: {
                Label("Invite Friends", systemImage: "person.badge.plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: manager.currentTier.gradientColors,
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Button {
                let caption = manager.getInstagramCaption(userName: AuthService.shared.currentUser?.name ?? "A friend")
                shareItems = [caption]
                showShareSheet = true
                manager.recordShare()
            } label: {
                Label("Instagram Caption", systemImage: "camera.fill")
                    .font(.subheadline)
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .pink, .orange], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(colors: [.purple, .pink, .orange], startPoint: .leading, endPoint: .trailing),
                                lineWidth: 1.5
                            )
                    )
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Referrals")
                .font(.headline)
            ForEach(manager.referralHistory.prefix(5)) { record in
                HStack {
                    Image(systemName: "person.fill.checkmark")
                        .foregroundStyle(.green)
                    Text(record.friendName)
                        .font(.subheadline)
                    Spacer()
                    Text("+\(record.xpEarned) XP")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var claimSection: some View {
        VStack(spacing: 8) {
            Text("Have a referral code?")
                .font(.subheadline.bold())
            Text("Enter a friend's code to get +100 XP bonus for both of you")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Enter Code") { showClaimAlert = true }
                .buttonStyle(.bordered)
                .tint(.blue)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func applyCode() {
        let success = manager.claimReferralCode(referralCodeInput)
        claimResult = success
            ? "Code applied! +100 XP added to your account 🎉"
            : (manager.isReferralClaimed ? "You've already used a code." : "Invalid or your own code.")
        referralCodeInput = ""
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
    NavigationStack { ReferralDashboardView() }
}
