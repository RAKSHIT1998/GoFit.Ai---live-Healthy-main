import SwiftUI

// MARK: - Share Your Story Dashboard Card
struct ShareYourStoryCard: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject private var streakManager = StreakManager.shared
    @ObservedObject private var referralManager = ReferralManager.shared
    
    @State private var showStoryBuilder = false
    @State private var selectedQuickTemplate: StoryTemplate = .dailyProgress
    @State private var carouselOffset: CGFloat = 0
    @State private var autoScrollTimer: Timer?
    @State private var currentIndex: Int = 0
    @State private var shimmerPhase: CGFloat = 0
    
    private let templates: [StoryTemplate] = [
        .dailyProgress, .streakFire, .workoutBeast, .mealScan, .levelUp, .weeklyRecap
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // Instagram gradient icon
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .pink, .orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        
                        Text("Share Your Story")
                            .font(Design.Typography.headline)
                    }
                    
                    Text("Show off your progress • Get friends to join!")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Share streak
                if referralManager.shareStreak > 0 {
                    HStack(spacing: 3) {
                        Text("📤")
                            .font(.caption)
                        Text("\(referralManager.shareStreak)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Design.Colors.primary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Design.Colors.primary.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Story template carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(templates) { template in
                        StoryTemplatePreviewCard(template: template) {
                            selectedQuickTemplate = template
                            showStoryBuilder = true
                            HapticManager.impact(style: .medium)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .frame(height: 200)
            
            // Quick share bar
            HStack(spacing: 12) {
                // Share to Instagram
                Button {
                    selectedQuickTemplate = suggestedTemplate
                    showStoryBuilder = true
                    HapticManager.impact(style: .medium)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12))
                        Text("Create Story")
                            .font(Design.Typography.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // Quick text share
                Button {
                    quickTextShare()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 12))
                        Text("Quick Share")
                            .font(Design.Typography.caption)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(Design.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Design.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Design.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.large, style: .continuous))
        .shadow(color: Color.purple.opacity(0.1), radius: 8, y: 4)
        .fullScreenCover(isPresented: $showStoryBuilder) {
            InstagramStoryBuilderView(initialTemplate: selectedQuickTemplate)
                .environmentObject(auth)
        }
    }
    
    private var suggestedTemplate: StoryTemplate {
        // Smart suggestion based on user data
        if streakManager.currentStreak >= 7 { return .streakFire }
        if streakManager.level > 1 { return .levelUp }
        return .dailyProgress
    }
    
    private func quickTextShare() {
        let text = ViralEngagementManager.motivationalShareTexts.randomElement() ?? ""
        let items: [Any] = [text]
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        let ac = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        if let popover = ac.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        rootVC.present(ac, animated: true)
        referralManager.recordShareActivity()
    }
}


// MARK: - Individual Story Template Preview Card
struct StoryTemplatePreviewCard: View {
    let template: StoryTemplate
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Mini story preview (9:16 ratio miniature)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: template.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Decorative elements
                VStack(spacing: 8) {
                    Spacer().frame(height: 16)
                    
                    // Template icon
                    Image(systemName: template.icon)
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.2), radius: 4)
                    
                    // Fake content lines
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 60, height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 40, height: 3)
                    }
                    
                    Spacer()
                    
                    // Fake stat boxes
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 20)
                        }
                    }
                    .padding(.horizontal, 8)
                    
                    Spacer().frame(height: 8)
                    
                    // GoFit.Ai brand
                    HStack(spacing: 2) {
                        Text("GoFit")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(".Ai")
                            .font(.system(size: 7, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer().frame(height: 10)
                }
                
                // Template name overlay at bottom
                VStack {
                    Spacer()
                    Text(template.title)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Capsule())
                        .padding(.bottom, 6)
                }
            }
            .frame(width: 110, height: 196) // 9:16 mini ratio
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: template.gradientColors.first?.opacity(0.3) ?? .clear, radius: 8, y: 4)
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isHovered = pressing
            }
        }, perform: {})
    }
}


// MARK: - Milestone Share Prompt (Shows after achievements)
struct MilestoneSharePrompt: View {
    let milestone: String
    let emoji: String
    let template: StoryTemplate
    @Binding var isPresented: Bool
    @EnvironmentObject var auth: AuthViewModel
    
    @State private var showStoryBuilder = false
    @State private var bounceAnimation = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Emoji with bounce
            Text(emoji)
                .font(.system(size: 60))
                .scaleEffect(bounceAnimation ? 1.2 : 0.8)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.4)
                    .repeatCount(3, autoreverses: true),
                    value: bounceAnimation
                )
            
            Text("🎉 Achievement Unlocked!")
                .font(Design.Typography.title2)
                .fontWeight(.bold)
            
            Text(milestone)
                .font(Design.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Share CTA
            Button {
                showStoryBuilder = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("Share to Instagram Story")
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            
            Button {
                isPresented = false
            } label: {
                Text("Maybe Later")
                    .font(Design.Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .background(Design.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.xlarge, style: .continuous))
        .shadow(radius: 20)
        .padding(.horizontal, 32)
        .onAppear {
            bounceAnimation = true
        }
        .fullScreenCover(isPresented: $showStoryBuilder) {
            InstagramStoryBuilderView(initialTemplate: template)
                .environmentObject(auth)
        }
    }
}
