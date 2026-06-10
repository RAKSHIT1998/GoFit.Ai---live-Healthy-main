import SwiftUI

// MARK: - Ambassador Hub Card
// The main entry point for the Instagram story / share flow.
// Designed to make users feel like proud brand ambassadors.

struct ShareYourStoryCard: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject private var streak   = StreakManager.shared
    @ObservedObject private var referral = ReferralManager.shared

    @State private var showStoryBuilder = false
    @State private var selectedTemplate: StoryTemplate = .ambassador
    @State private var showShareSheet   = false
    @State private var shareItems: [Any] = []
    @State private var glowPulse = false
    @State private var codeVisible = false

    var body: some View {
        VStack(spacing: 0) {
            heroHeader
            templateRow
            quickActions
        }
        .background(
            RoundedRectangle(cornerRadius: Design.Radius.xlarge)
                .fill(Design.Colors.cardBackground)
                .overlay(shimmerBorder)
        )
        .shadow(color: Design.Colors.primary.opacity(0.13), radius: 18, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        .fullScreenCover(isPresented: $showStoryBuilder) {
            InstagramStoryBuilderView(initialTemplate: selectedTemplate)
                .environmentObject(auth)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
        .onAppear { glowPulse = true }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        ZStack {
            // Aurora gradient background
            LinearGradient(
                colors: referral.currentTier.gradientColors + [Color(red: 0.839, green: 0.290, blue: 0.682).opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            // Ambient blobs
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 140, height: 140)
                .offset(x: 120, y: -30)
                .blur(radius: 20)
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 100, height: 100)
                .offset(x: -80, y: 20)
                .blur(radius: 16)

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    // Ambassador badge
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("AMBASSADOR")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.9))
                            .kerning(1.5)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Capsule())

                    Text("Share Your Story")
                        .font(Design.Typography.title3)
                        .foregroundStyle(.white)

                    Text("Turn your friends into fitness fans!")
                        .font(Design.Typography.caption)
                        .foregroundStyle(.white.opacity(0.80))
                }

                Spacer()

                // Tier circle
                VStack(spacing: 3) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 52, height: 52)
                            .scaleEffect(glowPulse ? 1.08 : 1.0)
                            .animation(
                                .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                value: glowPulse
                            )
                        Text(referral.currentTier.emoji)
                            .font(.system(size: 28))
                    }
                    Text(referral.currentTier.name)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(height: 110)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: Design.Radius.xlarge,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: Design.Radius.xlarge
            )
        )
    }

    // MARK: - Referral code strip + stats

    private var templateRow: some View {
        VStack(spacing: 10) {
            // Referral code quick-copy row
            if !referral.referralCode.isEmpty {
                referralCodeStrip
            }

            // Horizontal template scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(StoryTemplate.allCases) { template in
                        AmbassadorTemplateThumb(template: template) {
                            selectedTemplate = template
                            showStoryBuilder = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .frame(height: 178)
        }
        .padding(.top, 12)
    }

    private var referralCodeStrip: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR CODE")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(Design.Colors.primary.opacity(0.8))
                    .kerning(1.5)
                Text(referral.referralCode)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(Design.Colors.primary)
                    .kerning(3)
            }

            Spacer()

            // Stats pills
            HStack(spacing: 8) {
                miniPill(label: "\(referral.totalReferrals)", sublabel: "referred", color: Design.Colors.primary)
                miniPill(label: "\(referral.totalXPEarned)", sublabel: "XP", color: Design.Colors.accent)
            }

            // Copy button
            Button {
                UIPasteboard.general.string = referral.referralCode
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { codeVisible = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    withAnimation { codeVisible = false }
                }
            } label: {
                Image(systemName: codeVisible ? "checkmark.circle.fill" : "doc.on.doc.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(codeVisible ? Color(red: 0.063, green: 0.725, blue: 0.506) : Design.Colors.primary)
                    .animation(Design.Animation.springFast, value: codeVisible)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Design.Colors.primary.opacity(0.06))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Design.Colors.borderColor),
            alignment: .top
        )
    }

    private func miniPill(label: String, sublabel: String, color: Color) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(sublabel)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Quick action bar

    private var quickActions: some View {
        HStack(spacing: 10) {
            // Instagram story button
            Button {
                selectedTemplate = suggestedTemplate
                showStoryBuilder = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Create Story")
                        .font(Design.Typography.caption.bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.49, green: 0.16, blue: 0.82), Color(red: 0.95, green: 0.24, blue: 0.56), Color(red: 0.99, green: 0.62, blue: 0.04)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color(red: 0.95, green: 0.24, blue: 0.56).opacity(0.28), radius: 6, y: 2)
            }

            // Quick text share
            Button { quickTextShare() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble.fill")
                        .font(.system(size: 12))
                    Text("Quick Share")
                        .font(Design.Typography.caption.bold())
                }
                .foregroundStyle(Design.Colors.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Design.Colors.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }

    // MARK: - Helpers

    private var suggestedTemplate: StoryTemplate {
        if streak.currentStreak >= 7 { return .streakFire }
        if streak.level > 1 { return .levelUp }
        if !referral.referralCode.isEmpty { return .ambassador }
        return .dailyProgress
    }

    private func quickTextShare() {
        let texts = [
            "I'm leveling up my health with GoFit.Ai 💪 AI scans my meals, tracks my streak & keeps me accountable. Use code \(referral.referralCode) for free XP! #GoFitAi",
            "Day \(streak.currentStreak) of my health streak 🔥 GoFit.Ai makes staying healthy actually fun. Join me! Code: \(referral.referralCode) #GoFitAi #HealthyLife",
            "GoFit.Ai just roasted my diet and I'm SHOOK 😂 But also... it's right. AI-powered nutrition tracking is wild. Code: \(referral.referralCode) #GoFitAi"
        ]
        shareItems = [texts.randomElement() ?? texts[0]]
        showShareSheet = true
        referral.recordShareActivity()
    }

    private var shimmerBorder: some View {
        RoundedRectangle(cornerRadius: Design.Radius.xlarge)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.white.opacity(0.02), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }
}

// MARK: - Ambassador Template Thumbnail

struct AmbassadorTemplateThumb: View {
    let template: StoryTemplate
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Gradient fill
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: template.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Decorative shine
                LinearGradient(
                    colors: [Color.white.opacity(0.18), Color.clear],
                    startPoint: .top,
                    endPoint: .center
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(spacing: 7) {
                    Spacer().frame(height: 14)

                    // Icon
                    Image(systemName: template.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4)

                    // Fake content lines
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 54, height: 3.5)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.28))
                            .frame(width: 38, height: 2.5)
                    }

                    Spacer()

                    // Fake stat chips
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.18))
                                .frame(height: 16)
                        }
                    }
                    .padding(.horizontal, 7)

                    // Brand mark
                    HStack(spacing: 1) {
                        Text("GoFit").font(.system(size: 6.5, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text(".Ai").font(.system(size: 6.5, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.65))
                    }

                    Spacer().frame(height: 9)
                }

                // Name chip
                VStack {
                    Spacer()
                    HStack(spacing: 0) {
                        if template.isNew {
                            Text("✦ ")
                                .font(.system(size: 7, weight: .black))
                                .foregroundStyle(.white)
                        }
                        Text(template.title)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Color.black.opacity(0.38))
                    .clipShape(Capsule())
                    .padding(.bottom, 7)
                }
            }
            .frame(width: 100, height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(pressed ? 0.7 : 0.18), lineWidth: pressed ? 2 : 1)
            )
            .shadow(color: template.gradientColors.first?.opacity(0.25) ?? .clear, radius: 8, y: 3)
            .scaleEffect(pressed ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { p in
            withAnimation(Design.Animation.springFast) { pressed = p }
        }, perform: {})
    }
}

// MARK: - Milestone Share Prompt (shown after achievements)

struct MilestoneSharePrompt: View {
    let milestone: String
    let emoji: String
    let template: StoryTemplate
    @Binding var isPresented: Bool
    @EnvironmentObject var auth: AuthViewModel

    @State private var showStoryBuilder = false
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 20) {
            Text(emoji)
                .font(.system(size: 64))
                .scaleEffect(bounce ? 1.18 : 0.9)
                .animation(.spring(response: 0.45, dampingFraction: 0.4).repeatCount(3, autoreverses: true), value: bounce)
                .onAppear { bounce = true }

            VStack(spacing: 6) {
                Text("Achievement Unlocked!")
                    .font(Design.Typography.title2)
                    .foregroundStyle(.primary)
                Text(milestone)
                    .font(Design.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Instagram share CTA
            Button { showStoryBuilder = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("Share to Instagram Story")
                        .font(Design.Typography.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.49, green: 0.16, blue: 0.82), Color(red: 0.95, green: 0.24, blue: 0.56), Color(red: 0.99, green: 0.62, blue: 0.04)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color(red: 0.95, green: 0.24, blue: 0.56).opacity(0.35), radius: 10, y: 4)
            }

            Button { isPresented = false } label: {
                Text("Maybe Later")
                    .font(Design.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .background(Design.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.xlarge))
        .shadow(color: Design.Colors.primary.opacity(0.12), radius: 24)
        .padding(.horizontal, 28)
        .fullScreenCover(isPresented: $showStoryBuilder) {
            InstagramStoryBuilderView(initialTemplate: template)
                .environmentObject(auth)
        }
    }
}

