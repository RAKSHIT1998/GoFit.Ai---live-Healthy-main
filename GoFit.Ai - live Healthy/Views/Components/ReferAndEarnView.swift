import SwiftUI
import UIKit

// MARK: - Refer & Earn Dashboard Card (Compact)
struct ReferAndEarnCard: View {
    @ObservedObject private var referralManager = ReferralManager.shared
    @EnvironmentObject var auth: AuthViewModel
    @State private var showReferralHub = false
    @State private var showShareSheet = false
    @State private var codeCopied = false
    @State private var glowAnimation = false
    @State private var pulseCode = false
    
    var body: some View {
        Button {
            showReferralHub = true
            HapticManager.impact(style: .medium)
        } label: {
            VStack(spacing: 0) {
                // Top gradient banner
                ZStack {
                    // Animated gradient background
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.8, blue: 0.95),
                            Color(red: 0.4, green: 0.3, blue: 1.0),
                            Color(red: 0.8, green: 0.2, blue: 0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Floating gift particles
                    ForEach(0..<5, id: \.self) { i in
                        Text(["🎁", "💰", "⭐️", "🎉", "💎"][i])
                            .font(.system(size: CGFloat.random(in: 14...22)))
                            .offset(
                                x: CGFloat.random(in: -120...120),
                                y: glowAnimation ? CGFloat.random(in: -30...10) : CGFloat.random(in: -10...30)
                            )
                            .opacity(glowAnimation ? 0.9 : 0.4)
                            .animation(
                                .easeInOut(duration: Double.random(in: 2...3.5))
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.3),
                                value: glowAnimation
                            )
                    }
                    
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "gift.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .shadow(color: .white.opacity(0.5), radius: 4)
                                    
                                    Text("Refer & Earn")
                                        .font(Design.Typography.title3)
                                        .foregroundColor(.white)
                                        .fontWeight(.bold)
                                }
                                
                                Text("Invite friends, earn XP & unlock rewards!")
                                    .font(Design.Typography.caption)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                            
                            // Tier badge
                            VStack(spacing: 2) {
                                Text(referralManager.currentTier.emoji)
                                    .font(.system(size: 28))
                                    .scaleEffect(glowAnimation ? 1.1 : 1.0)
                                    .animation(
                                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                        value: glowAnimation
                                    )
                                Text(referralManager.currentTier.name)
                                    .font(Design.Typography.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .frame(height: 90)
                .clipShape(RoundedRectangle(cornerRadius: Design.Radius.large, style: .continuous))
                
                // Bottom stats bar
                HStack(spacing: 0) {
                    // Referrals count
                    VStack(spacing: 2) {
                        Text("\(referralManager.totalReferrals)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Design.Colors.primary)
                        Text("Referrals")
                            .font(Design.Typography.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Divider
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1, height: 30)
                    
                    // XP earned
                    VStack(spacing: 2) {
                        Text("\(referralManager.totalXPEarned)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Design.Colors.accent)
                        Text("XP Earned")
                            .font(Design.Typography.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Divider
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1, height: 30)
                    
                    // Quick share button
                    Button {
                        if referralManager.referralCode.isEmpty {
                            _ = referralManager.generateCode(
                                for: auth.userId ?? "user",
                                name: auth.name
                            )
                        }
                        showShareSheet = true
                        HapticManager.impact(style: .light)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Design.Colors.primaryGradient)
                                .clipShape(Circle())
                            Text("Share")
                                .font(Design.Typography.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 12)
                .background(Design.Colors.cardBackground)
                .clipShape(
                    RoundedRectangle(cornerRadius: Design.Radius.large, style: .continuous)
                )
            }
            .background(Design.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Design.Radius.large, style: .continuous))
            .shadow(color: Color.purple.opacity(0.15), radius: 12, y: 4)
        }
        .buttonStyle(SmoothButtonStyle())
        .onAppear {
            glowAnimation = true
            if referralManager.referralCode.isEmpty {
                _ = referralManager.generateCode(
                    for: auth.userId ?? "user",
                    name: auth.name
                )
            }
        }
        .sheet(isPresented: $showReferralHub) {
            ReferralHubView()
                .environmentObject(auth)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [
                referralManager.getInviteMessage(userName: auth.name)
            ])
        }
    }
}

// MARK: - Full Referral Hub View
struct ReferralHubView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject private var referralManager = ReferralManager.shared
    @State private var codeCopied = false
    @State private var showShareSheet = false
    @State private var selectedShareType: ShareType = .general
    @State private var incomingReferralCode = ""
    @State private var referralClaimMessage: String? = nil
    @State private var animateProgress = false
    @State private var showConfetti = false
    
    enum ShareType {
        case general, whatsapp, instagram, message
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Design.Colors.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero section
                        heroSection
                        
                        // Claim referral code (for existing users who got a code)
                        claimReferralSection

                        // Referral code card
                        referralCodeCard
                        
                        // Share buttons
                        shareButtonsSection
                        
                        // Tier progress
                        tierProgressSection
                        
                        // All tiers roadmap
                        tiersRoadmap
                        
                        // How it works
                        howItWorksSection
                        
                        // Referral history
                        if !referralManager.referralHistory.isEmpty {
                            referralHistorySection
                        }
                    }
                    .padding(.horizontal, Design.Spacing.md)
                    .padding(.bottom, 40)
                }
                
                // Confetti overlay
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Refer & Earn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                let message: String = {
                    switch selectedShareType {
                    case .instagram:
                        return referralManager.getInstagramCaption(userName: auth.name)
                    case .general, .whatsapp, .message:
                        return referralManager.getInviteMessage(userName: auth.name)
                    }
                }()
                ShareSheet(items: [message])
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).delay(0.3)) {
                    animateProgress = true
                }
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: referralManager.currentTier.gradientColors + [Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 200, height: 200)
                .offset(x: 100, y: -50)
            
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 150, height: 150)
                .offset(x: -80, y: 40)
            
            VStack(spacing: 12) {
                // Tier badge large
                Text(referralManager.currentTier.emoji)
                    .font(.system(size: 56))
                    .shadow(color: .black.opacity(0.2), radius: 8)
                
                Text(referralManager.currentTier.name + " Tier")
                    .font(Design.Typography.title)
                    .foregroundColor(.white)
                
                Text("\(referralManager.totalReferrals) friends referred")
                    .font(Design.Typography.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                // Total XP earned
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("\(referralManager.totalXPEarned) XP earned")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())
            }
            .padding(.vertical, 32)
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.xlarge, style: .continuous))
        .shadow(color: referralManager.currentTier.color.opacity(0.3), radius: 16, y: 8)
    }
    
    // MARK: - Referral Code Card
    private var referralCodeCard: some View {
        VStack(spacing: 16) {
            Text("Your Referral Code")
                .font(Design.Typography.headline)
                .foregroundColor(.secondary)
            
            // Code display
            HStack(spacing: 12) {
                Text(referralManager.referralCode.isEmpty ? "TAP TO GENERATE" : referralManager.referralCode)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(Design.Colors.primary)
                    .kerning(3)
                
                Button {
                    UIPasteboard.general.string = referralManager.referralCode
                    codeCopied = true
                    HapticManager.impact(style: .medium)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        codeCopied = false
                    }
                } label: {
                    Image(systemName: codeCopied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                        .font(.title3)
                        .foregroundColor(codeCopied ? .green : Design.Colors.primary)
                        .animation(.spring(), value: codeCopied)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        Design.Colors.primary.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Design.Colors.primary.opacity(0.05))
                    )
            )
            
            if codeCopied {
                Text("✅ Code copied to clipboard!")
                    .font(Design.Typography.caption)
                    .foregroundColor(.green)
                    .transition(.opacity.combined(with: .scale))
            }
            
            // Both earn message
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                    .foregroundColor(Design.Colors.primary)
                Text("You BOTH earn \(referralManager.currentTier.perReferralXP) XP per referral!")
                    .font(Design.Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .background(Design.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.large, style: .continuous))
    }
    
    // MARK: - Share Buttons
    private var shareButtonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share With Friends")
                .font(Design.Typography.headline)
            
            HStack(spacing: 12) {
                shareButton(
                    icon: "message.fill",
                    label: "Messages",
                    color: Color.green,
                    type: .message
                )
                
                shareButton(
                    icon: "paperplane.fill",
                    label: "WhatsApp",
                    color: Color(red: 0.07, green: 0.8, blue: 0.36),
                    type: .whatsapp
                )
                
                shareButton(
                    icon: "camera.fill",
                    label: "Instagram",
                    color: LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ).colors.first ?? .purple,
                    type: .instagram
                )
                
                shareButton(
                    icon: "square.and.arrow.up.fill",
                    label: "More",
                    color: Color.blue,
                    type: .general
                )
            }
        }
    }
    
    private func shareButton(icon: String, label: String, color: Color, type: ShareType) -> some View {
        Button {
            selectedShareType = type
            
            if type == .whatsapp {
                // Try to open WhatsApp directly
                let message = referralManager.getShortInvite(userName: auth.name)
                    .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "whatsapp://send?text=\(message)"),
                   UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                    referralManager.recordShareActivity()
                    return
                }
            }
            
            showShareSheet = true
            referralManager.recordShareActivity()
            HapticManager.impact(style: .light)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                Text(label)
                    .font(Design.Typography.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(SmoothButtonStyle())
    }
    
    // MARK: - Tier Progress
    private var tierProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let nextTier = referralManager.currentTier.nextTier {
                HStack {
                    Text("Next Tier: \(nextTier.emoji) \(nextTier.name)")
                        .font(Design.Typography.headline)
                    Spacer()
                    Text("\(referralManager.referralsToNextTier) more")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(height: 12)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: nextTier.gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: animateProgress ? geo.size.width * referralManager.progressToNextTier : 0,
                                height: 12
                            )
                            .animation(Design.Animation.spring, value: animateProgress)
                    }
                }
                .frame(height: 12)
                
                // Reward preview
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(nextTier.color)
                    Text(nextTier.perkDescription)
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Text("🏆 Maximum Tier Reached!")
                        .font(Design.Typography.headline)
                    Spacer()
                    Text(referralManager.currentTier.emoji)
                        .font(.title)
                }
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.large, style: .continuous))
    }
    
    // MARK: - Tiers Roadmap
    private var tiersRoadmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reward Tiers")
                .font(Design.Typography.headline)
            
            VStack(spacing: 8) {
                ForEach(ReferralTier.allCases, id: \.rawValue) { tier in
                    let isUnlocked = referralManager.totalReferrals >= tier.requiredReferrals
                    let isCurrent = referralManager.currentTier == tier
                    
                    HStack(spacing: 12) {
                        // Tier icon
                        Text(tier.emoji)
                            .font(.system(size: 24))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(isUnlocked ? tier.color.opacity(0.2) : Color.secondary.opacity(0.1))
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(tier.name)
                                    .font(Design.Typography.bodyBold)
                                    .foregroundColor(isUnlocked ? .primary : .secondary)
                                
                                if isCurrent {
                                    Text("CURRENT")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Design.Colors.primary)
                                        .clipShape(Capsule())
                                }
                                
                                if isUnlocked && !isCurrent {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                            }
                            
                            Text(tier == .starter ? "Start your journey" : "\(tier.requiredReferrals) referrals • \(tier.perkDescription)")
                                .font(Design.Typography.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // XP reward
                        if tier != .starter {
                            Text("+\(tier.xpReward) XP")
                                .font(Design.Typography.caption)
                                .fontWeight(.bold)
                                .foregroundColor(tier.color)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isCurrent ? tier.color.opacity(0.08) : Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(isCurrent ? tier.color.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.large, style: .continuous))
    }
    
    // MARK: - How It Works
    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How It Works")
                .font(Design.Typography.headline)
            
            VStack(spacing: 12) {
                howItWorksStep(number: 1, icon: "square.and.arrow.up", title: "Share Your Code", description: "Send your unique code to friends via any platform")
                howItWorksStep(number: 2, icon: "person.badge.plus", title: "Friend Signs Up", description: "They download GoFit.Ai and enter your code")
                howItWorksStep(number: 3, icon: "star.fill", title: "Both Earn XP!", description: "You both get \(referralManager.currentTier.perReferralXP) XP instantly + tier rewards")
                howItWorksStep(number: 4, icon: "arrow.up.right", title: "Level Up Tiers", description: "More referrals = higher tier = bigger rewards!")
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.large, style: .continuous))
    }
    
    private func howItWorksStep(number: Int, icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Design.Colors.primaryGradient)
                    .frame(width: 36, height: 36)
                
                Text("\(number)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Design.Typography.bodyBold)
                Text(description)
                    .font(Design.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Referral History
    private var referralHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Referral History")
                    .font(Design.Typography.headline)
                Spacer()
                Text("\(referralManager.referralHistory.count) total")
                    .font(Design.Typography.caption)
                    .foregroundColor(.secondary)
            }
            
            ForEach(referralManager.referralHistory.prefix(10)) { record in
                HStack(spacing: 12) {
                    // Avatar
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: record.tierAtTime.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(record.friendName.prefix(1)).uppercased())
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.friendName)
                            .font(Design.Typography.bodyBold)
                        Text(record.date, style: .relative)
                            .font(Design.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("+\(record.xpEarned) XP")
                        .font(Design.Typography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Design.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Design.Colors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.large, style: .continuous))
    }
}

private extension ReferralHubView {
    var claimReferralSection: some View {
    VStack(spacing: 10) {
        Text("Redeem friend referral code")
            .font(Design.Typography.subheadline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)

        HStack(spacing: 8) {
            TextField("Enter referral code", text: $incomingReferralCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.allCharacters)
                .disableAutocorrection(true)

            Button("Claim") {
                let clean = incomingReferralCode.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !clean.isEmpty else { return }

                if referralManager.claimReferralCode(clean) {
                    referralClaimMessage = "Success! 100 XP claimed from referral code."
                    incomingReferralCode = ""
                    showConfetti = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showConfetti = false
                    }
                } else {
                    referralClaimMessage = "Could not claim code. It may be invalid, already claimed, or match your own."
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(incomingReferralCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }

        if let referralClaimMessage {
            Text(referralClaimMessage)
                .font(Design.Typography.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .padding(12)
    .background(Design.Colors.cardBackground)
    .clipShape(RoundedRectangle(cornerRadius: Design.Radius.medium, style: .continuous))
    .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 2)
    }
}

// MARK: - Helper: LinearGradient colors extension
extension LinearGradient {
    var colors: [Color] { [] }  // Stub for compilation
}
