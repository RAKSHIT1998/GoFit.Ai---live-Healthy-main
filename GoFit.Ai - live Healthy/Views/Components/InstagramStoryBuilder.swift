import SwiftUI

// MARK: - Story Template Type
enum StoryTemplate: String, CaseIterable, Identifiable {
    case ambassador = "ambassador"   // ← NEW: VIP brand ambassador card
    case workoutBeast = "workout"
    case streakFire = "streak"
    case mealScan = "meal"
    case weeklyRecap = "weekly"
    case levelUp = "level"
    case challengeWin = "challenge"
    case beforeAfter = "transformation"
    case dailyProgress = "daily"

    var id: String { rawValue }

    var isNew: Bool { self == .ambassador }
    
    var title: String {
        switch self {
        case .ambassador:   return "Ambassador"
        case .workoutBeast: return "Workout Beast"
        case .streakFire:   return "Streak Fire"
        case .mealScan:     return "Meal Scan"
        case .weeklyRecap:  return "Weekly Recap"
        case .levelUp:      return "Level Up"
        case .challengeWin: return "Challenge Won"
        case .beforeAfter:  return "My Journey"
        case .dailyProgress: return "Daily Progress"
        }
    }

    var icon: String {
        switch self {
        case .ambassador:   return "star.circle.fill"
        case .workoutBeast: return "figure.run"
        case .streakFire:   return "flame.fill"
        case .mealScan:     return "fork.knife"
        case .weeklyRecap:  return "chart.bar.fill"
        case .levelUp:      return "arrow.up.circle.fill"
        case .challengeWin: return "trophy.fill"
        case .beforeAfter:  return "arrow.right.arrow.left"
        case .dailyProgress: return "chart.line.uptrend.xyaxis"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .ambassador:   return [Color(red: 0.310, green: 0.275, blue: 0.898), Color(red: 0.486, green: 0.231, blue: 0.929), Color(red: 0.839, green: 0.290, blue: 0.682)]
        case .workoutBeast: return [Color(red: 0.0, green: 0.8, blue: 0.5), Color(red: 0.0, green: 0.4, blue: 0.9)]
        case .streakFire:   return [Color(red: 1.0, green: 0.3, blue: 0.0), Color(red: 1.0, green: 0.7, blue: 0.0)]
        case .mealScan:     return [Color(red: 0.2, green: 0.85, blue: 0.4), Color(red: 0.0, green: 0.6, blue: 0.3)]
        case .weeklyRecap:  return [Color(red: 0.4, green: 0.2, blue: 1.0), Color(red: 0.7, green: 0.3, blue: 1.0)]
        case .levelUp:      return [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.5, blue: 0.0)]
        case .challengeWin: return [Color(red: 0.9, green: 0.2, blue: 0.5), Color(red: 0.5, green: 0.0, blue: 0.8)]
        case .beforeAfter:  return [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.3, green: 0.1, blue: 0.5)]
        case .dailyProgress: return [Color(red: 0.0, green: 0.6, blue: 0.9), Color(red: 0.0, green: 0.3, blue: 0.7)]
        }
    }
}

// MARK: - Story Data
struct StoryData {
    var userName: String = ""
    var calories: String = "0"
    var steps: Int = 0
    var activeCalories: Double = 0
    var waterIntake: Double = 0
    var streakDays: Int = 0
    var level: Int = 1
    var levelTitle: String = "Beginner"
    var totalPoints: Int = 0
    var workoutsThisWeek: Int = 0
    var mealsLogged: Int = 0
    var referralCode: String = ""
}

// MARK: - Instagram Story Builder View
struct InstagramStoryBuilderView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var auth: AuthViewModel
    
    let initialTemplate: StoryTemplate
    
    @State private var selectedTemplate: StoryTemplate
    @State private var storyData = StoryData()
    @State private var renderedImage: UIImage?
    @State private var showShareSheet = false
    @State private var isRendering = false
    @State private var previewScale: CGFloat = 0.9
    @State private var showSharedCelebration = false
    @State private var sharedXP = 0
    
    @ObservedObject private var streakManager = StreakManager.shared
    @ObservedObject private var referralManager = ReferralManager.shared
    
    init(initialTemplate: StoryTemplate = .dailyProgress) {
        self.initialTemplate = initialTemplate
        _selectedTemplate = State(initialValue: initialTemplate)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // PULSE dark background
                Color(red: 0.031, green: 0.043, blue: 0.078).ignoresSafeArea()

                // Ambient glow behind preview
                Ellipse()
                    .fill(Design.Colors.primary.opacity(0.12))
                    .frame(width: 260, height: 180)
                    .blur(radius: 60)
                    .offset(y: -40)

                VStack(spacing: 0) {
                    // Ambassador rank strip
                    ambassadorStrip.padding(.top, 8)

                    // Template picker
                    templatePicker.padding(.top, 10)

                    // Story preview
                    GeometryReader { geo in
                        let previewWidth = min(geo.size.width - 40, 300)
                        let previewHeight = previewWidth * (16.0 / 9.0)

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 20) {
                                storyPreview(width: previewWidth, height: previewHeight)
                                    .scaleEffect(previewScale)
                                    .onAppear {
                                        withAnimation(Design.Animation.spring) { previewScale = 1.0 }
                                    }
                                    .onChange(of: selectedTemplate) {
                                        previewScale = 0.88
                                        withAnimation(Design.Animation.spring) { previewScale = 1.0 }
                                    }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                    }

                    actionButtons.padding(.bottom, 24)
                }

                // Post-share XP celebration overlay
                if showSharedCelebration {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Text("⚡")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("+\(sharedXP) XP Earned!")
                                    .font(Design.Typography.bodyBold)
                                    .foregroundStyle(.white)
                                Text("Your code is on the story — keep sharing!")
                                    .font(Design.Typography.caption)
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Design.Colors.primaryGradient)
                                .shadow(color: Design.Colors.primary.opacity(0.4), radius: 12)
                        )
                        .padding(.bottom, 100)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Story Studio")
                        .font(Design.Typography.headline)
                        .foregroundStyle(.white)
                }
            }
            .onAppear { populateStoryData() }
            .sheet(isPresented: $showShareSheet) {
                if let image = renderedImage {
                    ShareSheet(items: [
                        image,
                        "Crushing my fitness goals with @GoFit.Ai 💪 Code: \(storyData.referralCode) #GoFitAi #Fitness"
                    ])
                }
            }
        }
    }

    // MARK: - Ambassador strip
    private var ambassadorStrip: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Design.Colors.primary)
            Text("GoFit.Ai Ambassador")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text(referralManager.currentTier.emoji + " " + referralManager.currentTier.name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
        .padding(.horizontal, 16)
    }
    
    // MARK: - Template Picker
    private var templatePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(StoryTemplate.allCases) { template in
                    Button {
                        withAnimation(Design.Animation.spring) { selectedTemplate = template }
                        HapticManager.impact(style: .light)
                    } label: {
                        VStack(spacing: 6) {
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: template.gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 54, height: 54)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(
                                                selectedTemplate == template
                                                    ? Color.white
                                                    : Color.white.opacity(0.12),
                                                lineWidth: selectedTemplate == template ? 2.5 : 1
                                            )
                                    )
                                    .shadow(
                                        color: template.gradientColors.first?.opacity(selectedTemplate == template ? 0.5 : 0.0) ?? .clear,
                                        radius: 10
                                    )
                                    .overlay(
                                        Image(systemName: template.icon)
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white)
                                    )

                                // "NEW" badge on ambassador
                                if template.isNew {
                                    Text("NEW")
                                        .font(.system(size: 7, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color(red: 0.937, green: 0.267, blue: 0.267))
                                        .clipShape(Capsule())
                                        .offset(x: 4, y: -4)
                                }
                            }

                            Text(template.title)
                                .font(.system(size: 10, weight: selectedTemplate == template ? .bold : .medium, design: .rounded))
                                .foregroundStyle(selectedTemplate == template ? Color.white : Color.white.opacity(0.45))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Story Preview
    @ViewBuilder
    private func storyPreview(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            switch selectedTemplate {
            case .ambassador:
                AmbassadorStory(data: storyData, tier: referralManager.currentTier, size: CGSize(width: width, height: height))
            case .workoutBeast:
                WorkoutBeastStory(data: storyData, size: CGSize(width: width, height: height))
            case .streakFire:
                StreakFireStory(data: storyData, size: CGSize(width: width, height: height))
            case .mealScan:
                MealScanStory(data: storyData, size: CGSize(width: width, height: height))
            case .weeklyRecap:
                WeeklyRecapStory(data: storyData, size: CGSize(width: width, height: height))
            case .levelUp:
                LevelUpStory(data: storyData, size: CGSize(width: width, height: height))
            case .challengeWin:
                ChallengeWinStory(data: storyData, size: CGSize(width: width, height: height))
            case .beforeAfter:
                JourneyStory(data: storyData, size: CGSize(width: width, height: height))
            case .dailyProgress:
                DailyProgressStory(data: storyData, size: CGSize(width: width, height: height))
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: selectedTemplate.gradientColors.first?.opacity(0.5) ?? .clear, radius: 20, y: 10)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Primary: Instagram Stories
            Button {
                renderAndShareToInstagram()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Share to Instagram Story")
                        .font(Design.Typography.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.49, green: 0.16, blue: 0.82), Color(red: 0.95, green: 0.24, blue: 0.56), Color(red: 0.99, green: 0.62, blue: 0.04)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.15), Color.clear], startPoint: .top, endPoint: .center))
                )
                .shadow(color: Color(red: 0.95, green: 0.24, blue: 0.56).opacity(0.4), radius: 12, y: 4)
            }
            .buttonStyle(AnimatedButtonStyle(color: .pink, isPrimary: true))

            // Secondary row
            HStack(spacing: 10) {
                // General share
                Button {
                    renderAndShare()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("Share")
                            .font(Design.Typography.subheadline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }

                // Copy referral code quick action
                if !storyData.referralCode.isEmpty {
                    Button {
                        UIPasteboard.general.string = storyData.referralCode
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                            Text("Copy Code")
                                .font(Design.Typography.subheadline)
                        }
                        .foregroundStyle(Design.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Design.Colors.primary.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Render & Share

    private func showXPCelebration() {
        sharedXP = 50
        withAnimation(Design.Animation.spring) { showSharedCelebration = true }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { showSharedCelebration = false }
        }
    }

    private func renderAndShare() {
        isRendering = true
        let size = CGSize(width: 1080, height: 1920)
        renderedImage = renderStoryToImage(size: size)
        isRendering = false
        showShareSheet = true
        ReferralManager.shared.recordShare()
        showXPCelebration()
    }

    private func renderAndShareToInstagram() {
        let size = CGSize(width: 1080, height: 1920)
        guard let image = renderStoryToImage(size: size) else { return }

        if let imageData = image.pngData() {
            let pasteboardItems: [String: Any] = [
                "com.instagram.sharedSticker.backgroundImage": imageData,
                "com.instagram.sharedSticker.contentURL": "https://apps.apple.com/app/gofit-ai"
            ]
            UIPasteboard.general.setItems([pasteboardItems], options: [
                .expirationDate: Date().addingTimeInterval(60 * 5)
            ])

            if let url = URL(string: "instagram-stories://share?source_application=com.gofit.ai"),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                ReferralManager.shared.recordShare()
                showXPCelebration()
            } else {
                renderedImage = image
                showShareSheet = true
                ReferralManager.shared.recordShare()
                showXPCelebration()
            }
        }
    }
    
    @MainActor
    private func renderStoryToImage(size: CGSize) -> UIImage? {
        let storyView: AnyView
        
        switch selectedTemplate {
        case .ambassador:
            storyView = AnyView(AmbassadorStory(data: storyData, tier: referralManager.currentTier, size: size))
        case .workoutBeast:
            storyView = AnyView(WorkoutBeastStory(data: storyData, size: size))
        case .streakFire:
            storyView = AnyView(StreakFireStory(data: storyData, size: size))
        case .mealScan:
            storyView = AnyView(MealScanStory(data: storyData, size: size))
        case .weeklyRecap:
            storyView = AnyView(WeeklyRecapStory(data: storyData, size: size))
        case .levelUp:
            storyView = AnyView(LevelUpStory(data: storyData, size: size))
        case .challengeWin:
            storyView = AnyView(ChallengeWinStory(data: storyData, size: size))
        case .beforeAfter:
            storyView = AnyView(JourneyStory(data: storyData, size: size))
        case .dailyProgress:
            storyView = AnyView(DailyProgressStory(data: storyData, size: size))
        }
        
        let controller = UIHostingController(rootView: storyView.frame(width: size.width, height: size.height))
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear
        
        // Force layout
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }
    
    // MARK: - Populate Data
    private func populateStoryData() {
        let broadcaster = NutritionBroadcaster.shared
        broadcaster.refreshFromLocalStorage()

        let todayLog = LocalDailyLogStore.shared.getTodayLog()
        let mealCacheTotals = LocalMealCache.shared.getTodayTotals()
        let fallbackStats = UserDataCache.shared.calculateTodaysStats()

        let caloriesConsumed = max(todayLog.totalCalories, max(mealCacheTotals.calories, fallbackStats.totalCaloriesConsumed))
        let steps = todayLog.steps ?? fallbackStats.steps
        let activeCalories = max(todayLog.caloriesBurned, fallbackStats.totalCaloriesBurned)
        let water = max(todayLog.totalLiquid, fallbackStats.waterIntake)
        let mealsLogged = max(todayLog.meals.count, max(LocalMealCache.shared.getTodayMeals().count, fallbackStats.mealsLogged))
        let workoutsThisWeek = fallbackStats.workoutsCompleted

        storyData = StoryData(
            userName: auth.name,
            calories: NumberFormatter.localizedString(from: NSNumber(value: Int(caloriesConsumed)), number: .decimal),
            steps: steps,
            activeCalories: activeCalories,
            waterIntake: water,
            streakDays: streakManager.currentStreak,
            level: streakManager.level,
            levelTitle: streakManager.levelTitle,
            totalPoints: streakManager.totalPoints,
            workoutsThisWeek: workoutsThisWeek,
            mealsLogged: mealsLogged,
            referralCode: referralManager.referralCode
        )
    }
}


// MARK: - Story Template Views

// ============================================================
// 1. WORKOUT BEAST STORY
// ============================================================
struct WorkoutBeastStory: View {
    let data: StoryData
    let size: CGSize
    
    private var scale: CGFloat { size.width / 1080.0 }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.1, blue: 0.15),
                    Color(red: 0.0, green: 0.3, blue: 0.2),
                    Color(red: 0.0, green: 0.1, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Neon grid lines
            neonGrid
            
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.08)
                
                // Top badge
                HStack(spacing: 6 * scale) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8 * scale, height: 8 * scale)
                    Text("LIVE TRACKING")
                        .font(.system(size: 11 * scale, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                        .kerning(2)
                }
                .padding(.horizontal, 12 * scale)
                .padding(.vertical, 6 * scale)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.green.opacity(0.3), lineWidth: 1))
                
                Spacer().frame(height: size.height * 0.06)
                
                // Big emoji
                Text("🏋️‍♂️")
                    .font(.system(size: 80 * scale))
                
                Text("WORKOUT")
                    .font(.system(size: 48 * scale, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .kerning(4)
                
                Text("BEAST MODE")
                    .font(.system(size: 28 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.2, green: 1.0, blue: 0.5))
                    .kerning(6)
                
                Spacer().frame(height: size.height * 0.05)
                
                // Stats cards
                VStack(spacing: 12 * scale) {
                    storyStatBar(icon: "🔥", label: "CALORIES BURNED", value: "\(Int(data.activeCalories))", color: .orange)
                    storyStatBar(icon: "👣", label: "STEPS TODAY", value: "\(data.steps.formatted())", color: .cyan)
                    storyStatBar(icon: "💧", label: "WATER INTAKE", value: "\(String(format: "%.1f", data.waterIntake))L", color: .blue)
                    storyStatBar(icon: "⚡", label: "ACTIVE MINUTES", value: "45", color: .yellow)
                }
                .padding(.horizontal, 24 * scale)
                
                Spacer()
                
                // Bottom branding
                storyBranding
                
                Spacer().frame(height: size.height * 0.05)
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    private var neonGrid: some View {
        Canvas { context, canvasSize in
            let lineColor = Color.green.opacity(0.08)
            let spacing: CGFloat = 40 * scale
            
            for i in stride(from: 0, to: canvasSize.width, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: i, y: 0))
                path.addLine(to: CGPoint(x: i, y: canvasSize.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
            for j in stride(from: 0, to: canvasSize.height, by: spacing) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: j))
                path.addLine(to: CGPoint(x: canvasSize.width, y: j))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
        }
    }
    
    private func storyStatBar(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Text(icon)
                .font(.system(size: 20 * scale))
            
            VStack(alignment: .leading, spacing: 2 * scale) {
                Text(label)
                    .font(.system(size: 9 * scale, weight: .medium, design: .monospaced))
                    .foregroundColor(color.opacity(0.8))
                    .kerning(1)
                Text(value)
                    .font(.system(size: 22 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Mini bar
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.3))
                .frame(width: 60 * scale, height: 6 * scale)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: CGFloat.random(in: 25...55) * scale, height: 6 * scale)
                }
        }
        .padding(.horizontal, 16 * scale)
        .padding(.vertical, 12 * scale)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var storyBranding: some View {
        VStack(spacing: 8 * scale) {
            if !data.referralCode.isEmpty {
                HStack(spacing: 6 * scale) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 12 * scale))
                        .foregroundColor(.yellow)
                    Text("Code: \(data.referralCode)")
                        .font(.system(size: 13 * scale, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 16 * scale)
                .padding(.vertical, 8 * scale)
                .background(Color.yellow.opacity(0.15))
                .clipShape(Capsule())
            }
            
            HStack(spacing: 4 * scale) {
                Text("GoFit")
                    .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(".Ai")
                    .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
            }
            
            Text("AI-Powered Fitness • Free on App Store")
                .font(.system(size: 10 * scale, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}


// ============================================================
// 2. STREAK FIRE STORY
// ============================================================
struct StreakFireStory: View {
    let data: StoryData
    let size: CGSize
    
    private var scale: CGFloat { size.width / 1080.0 }
    
    var body: some View {
        ZStack {
            // Hot gradient
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.0, blue: 0.0),
                    Color(red: 0.6, green: 0.1, blue: 0.0),
                    Color(red: 0.9, green: 0.3, blue: 0.0),
                    Color(red: 1.0, green: 0.6, blue: 0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Fire particles
            ForEach(0..<15, id: \.self) { i in
                Text("🔥")
                    .font(.system(size: CGFloat.random(in: 16...40) * scale))
                    .opacity(Double.random(in: 0.1...0.4))
                    .position(
                        x: CGFloat.random(in: 0...size.width),
                        y: CGFloat.random(in: 0...size.height)
                    )
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.1)
                
                // Streak number - HUGE
                Text("🔥")
                    .font(.system(size: 100 * scale))
                
                Text("\(data.streakDays)")
                    .font(.system(size: 120 * scale, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .orange.opacity(0.6), radius: 20 * scale)
                
                Text("DAY STREAK")
                    .font(.system(size: 28 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .kerning(8)
                
                Spacer().frame(height: size.height * 0.06)
                
                // Motivational text
                Text(streakMotivation)
                    .font(.system(size: 18 * scale, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40 * scale)
                
                Spacer().frame(height: size.height * 0.06)
                
                // Stats row
                HStack(spacing: 20 * scale) {
                    miniStatPill(emoji: "⚡", value: "\(data.totalPoints)", label: "XP")
                    miniStatPill(emoji: "🏆", value: "Lv.\(data.level)", label: data.levelTitle)
                    miniStatPill(emoji: "🍽️", value: "\(data.mealsLogged)", label: "Meals")
                }
                
                Spacer()
                
                // Branding + referral
                VStack(spacing: 8 * scale) {
                    if !data.referralCode.isEmpty {
                        Text("Join me! Code: \(data.referralCode)")
                            .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20 * scale)
                            .padding(.vertical, 10 * scale)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 4 * scale) {
                        Text("GoFit")
                            .font(.system(size: 18 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(".Ai")
                            .font(.system(size: 18 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                    }
                    Text("Download Free on App Store")
                        .font(.system(size: 10 * scale, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer().frame(height: size.height * 0.05)
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    private var streakMotivation: String {
        if data.streakDays >= 30 { return "A WHOLE MONTH of consistency!\nNothing can stop me! 💪" }
        if data.streakDays >= 14 { return "Two weeks strong!\nThis is becoming a lifestyle! 🚀" }
        if data.streakDays >= 7 { return "One week down!\nBuilding unstoppable habits! ⚡" }
        return "Every day counts!\nConsistency is my superpower! ✨"
    }
    
    private func miniStatPill(emoji: String, value: String, label: String) -> some View {
        VStack(spacing: 4 * scale) {
            Text(emoji)
                .font(.system(size: 24 * scale))
            Text(value)
                .font(.system(size: 18 * scale, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10 * scale, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 14 * scale)
        .padding(.vertical, 12 * scale)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
    }
}


// ============================================================
// 3. MEAL SCAN STORY
// ============================================================
struct MealScanStory: View {
    let data: StoryData
    let size: CGSize
    
    private var scale: CGFloat { size.width / 1080.0 }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.15, blue: 0.05),
                    Color(red: 0.1, green: 0.3, blue: 0.1),
                    Color(red: 0.05, green: 0.15, blue: 0.05)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Food emojis scattered
            ForEach(0..<12, id: \.self) { i in
                Text(["🥗", "🥑", "🍗", "🥩", "🍳", "🥦", "🍎", "🥕", "🍣", "🥜", "🫐", "🍌"][i])
                    .font(.system(size: CGFloat.random(in: 20...35) * scale))
                    .opacity(Double.random(in: 0.1...0.25))
                    .position(
                        x: CGFloat.random(in: 20...size.width - 20),
                        y: CGFloat.random(in: 20...size.height - 20)
                    )
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.08)
                
                // Scanner animation
                HStack(spacing: 6 * scale) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 14 * scale))
                        .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                    Text("AI MEAL SCAN")
                        .font(.system(size: 12 * scale, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                        .kerning(2)
                }
                .padding(.horizontal, 16 * scale)
                .padding(.vertical, 8 * scale)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
                
                Spacer().frame(height: size.height * 0.04)
                
                Text("📸")
                    .font(.system(size: 70 * scale))
                
                Text("SCANNED IN")
                    .font(.system(size: 20 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .kerning(3)
                
                Text("2 SECONDS")
                    .font(.system(size: 44 * scale, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Full nutrition breakdown instantly!")
                    .font(.system(size: 14 * scale, weight: .medium, design: .rounded))
                    .foregroundColor(.green.opacity(0.8))
                
                Spacer().frame(height: size.height * 0.05)
                
                // Nutrition breakdown card
                VStack(spacing: 10 * scale) {
                    nutritionRow(label: "Calories", value: data.calories, color: .orange, percent: 0.7)
                    nutritionRow(label: "Protein", value: "45g", color: .blue, percent: 0.85)
                    nutritionRow(label: "Carbs", value: "65g", color: .red, percent: 0.6)
                    nutritionRow(label: "Fat", value: "22g", color: .yellow, percent: 0.45)
                    nutritionRow(label: "Fiber", value: "8g", color: .green, percent: 0.55)
                }
                .padding(20 * scale)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20 * scale, style: .continuous))
                .padding(.horizontal, 24 * scale)
                
                Spacer().frame(height: size.height * 0.04)
                
                Text("\(data.mealsLogged) meals logged this week 🎯")
                    .font(.system(size: 14 * scale, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                // Branding
                VStack(spacing: 6 * scale) {
                    if !data.referralCode.isEmpty {
                        Text("Try it free! Code: \(data.referralCode)")
                            .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16 * scale)
                            .padding(.vertical, 8 * scale)
                            .background(Color.green.opacity(0.3))
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 4 * scale) {
                        Text("GoFit")
                            .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(".Ai")
                            .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                    }
                    Text("AI-Powered Nutrition • Free on App Store")
                        .font(.system(size: 10 * scale, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer().frame(height: size.height * 0.05)
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func nutritionRow(label: String, value: String, color: Color, percent: Double) -> some View {
        HStack(spacing: 10 * scale) {
            Text(label)
                .font(.system(size: 13 * scale, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 60 * scale, alignment: .leading)
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * percent)
                }
            }
            .frame(height: 8 * scale)
            
            Text(value)
                .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 50 * scale, alignment: .trailing)
        }
    }
}


// ============================================================
// 4. WEEKLY RECAP STORY
// ============================================================
struct WeeklyRecapStory: View {
    let data: StoryData
    let size: CGSize
    
    private var scale: CGFloat { size.width / 1080.0 }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.05, blue: 0.25),
                    Color(red: 0.2, green: 0.1, blue: 0.4),
                    Color(red: 0.3, green: 0.15, blue: 0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Star particles
            ForEach(0..<20, id: \.self) { _ in
                Circle()
                    .fill(Color.white)
                    .frame(width: CGFloat.random(in: 1...3) * scale)
                    .position(
                        x: CGFloat.random(in: 0...size.width),
                        y: CGFloat.random(in: 0...size.height)
                    )
                    .opacity(Double.random(in: 0.2...0.6))
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.08)
                
                Text("📊")
                    .font(.system(size: 60 * scale))
                
                Text("MY WEEK")
                    .font(.system(size: 42 * scale, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .kerning(4)
                
                Text("IN REVIEW")
                    .font(.system(size: 24 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(.purple.opacity(0.8))
                    .kerning(6)
                
                Spacer().frame(height: size.height * 0.04)
                
                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12 * scale),
                    GridItem(.flexible(), spacing: 12 * scale)
                ], spacing: 12 * scale) {
                    recapStatBox(emoji: "🔥", value: data.calories, label: "Avg Calories", color: .orange)
                    recapStatBox(emoji: "👣", value: "\(data.steps.formatted())", label: "Avg Steps", color: .cyan)
                    recapStatBox(emoji: "💪", value: "\(data.workoutsThisWeek)", label: "Workouts", color: .green)
                    recapStatBox(emoji: "🍽️", value: "\(data.mealsLogged)", label: "Meals Logged", color: .pink)
                    recapStatBox(emoji: "💧", value: "\(String(format: "%.1f", data.waterIntake))L", label: "Avg Water", color: .blue)
                    recapStatBox(emoji: "🔥", value: "\(data.streakDays) days", label: "Streak", color: .orange)
                }
                .padding(.horizontal, 24 * scale)
                
                Spacer().frame(height: size.height * 0.04)
                
                // Weekly bar chart
                weeklyBarChart
                
                Spacer()
                
                // Branding
                VStack(spacing: 6 * scale) {
                    if !data.referralCode.isEmpty {
                        Text("Track yours too! Code: \(data.referralCode)")
                            .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16 * scale)
                            .padding(.vertical, 8 * scale)
                            .background(Color.purple.opacity(0.3))
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 4 * scale) {
                        Text("GoFit")
                            .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(".Ai")
                            .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                    }
                    Text("AI-Powered Fitness • Free Download")
                        .font(.system(size: 10 * scale, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer().frame(height: size.height * 0.05)
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func recapStatBox(emoji: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6 * scale) {
            Text(emoji)
                .font(.system(size: 22 * scale))
            Text(value)
                .font(.system(size: 20 * scale, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10 * scale, weight: .medium, design: .rounded))
                .foregroundColor(color.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14 * scale)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var weeklyBarChart: some View {
        let days = ["M", "T", "W", "T", "F", "S", "S"]
        let values: [CGFloat] = [0.6, 0.8, 0.5, 0.9, 0.7, 0.4, 0.85]
        
        return HStack(alignment: .bottom, spacing: 8 * scale) {
            ForEach(0..<7, id: \.self) { i in
                VStack(spacing: 4 * scale) {
                    RoundedRectangle(cornerRadius: 4 * scale)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.pink],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 20 * scale, height: 60 * scale * values[i])
                    
                    Text(days[i])
                        .font(.system(size: 10 * scale, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 40 * scale)
    }
}


// ============================================================
// 5. LEVEL UP STORY
// ============================================================
struct LevelUpStory: View {
    let data: StoryData
    let size: CGSize
    
    private var scale: CGFloat { size.width / 1080.0 }
    
    var body: some View {
        ZStack {
            // Golden gradient
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.1, blue: 0.0),
                    Color(red: 0.4, green: 0.25, blue: 0.0),
                    Color(red: 0.6, green: 0.4, blue: 0.0),
                    Color(red: 0.15, green: 0.1, blue: 0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Sparkle particles
            ForEach(0..<18, id: \.self) { _ in
                Text("✨")
                    .font(.system(size: CGFloat.random(in: 12...24) * scale))
                    .position(
                        x: CGFloat.random(in: 0...size.width),
                        y: CGFloat.random(in: 0...size.height)
                    )
                    .opacity(Double.random(in: 0.2...0.6))
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.12)
                
                // Crown
                Text("👑")
                    .font(.system(size: 80 * scale))
                
                Spacer().frame(height: size.height * 0.02)
                
                Text("LEVEL UP!")
                    .font(.system(size: 48 * scale, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                    .shadow(color: .orange.opacity(0.5), radius: 10 * scale)
                
                Spacer().frame(height: size.height * 0.03)
                
                // Level number with ring
                ZStack {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.yellow, .orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 4 * scale
                        )
                        .frame(width: 120 * scale, height: 120 * scale)
                    
                    VStack(spacing: 0) {
                        Text("\(data.level)")
                            .font(.system(size: 56 * scale, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text(data.levelTitle.uppercased())
                            .font(.system(size: 10 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                            .kerning(2)
                    }
                }
                
                Spacer().frame(height: size.height * 0.05)
                
                // Total XP
                VStack(spacing: 4 * scale) {
                    Text("TOTAL XP")
                        .font(.system(size: 12 * scale, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow.opacity(0.7))
                        .kerning(3)
                    Text("\(data.totalPoints)")
                        .font(.system(size: 36 * scale, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer().frame(height: size.height * 0.04)
                
                // Achievement badges
                HStack(spacing: 16 * scale) {
                    achievementBadge(emoji: "🔥", label: "\(data.streakDays)d Streak")
                    achievementBadge(emoji: "🍽️", label: "\(data.mealsLogged) Meals")
                    achievementBadge(emoji: "💪", label: "\(data.workoutsThisWeek) Workouts")
                }
                
                Spacer()
                
                // Branding
                VStack(spacing: 6 * scale) {
                    if !data.referralCode.isEmpty {
                        Text("Level up with me! Code: \(data.referralCode)")
                            .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 16 * scale)
                            .padding(.vertical, 8 * scale)
                            .background(Color.yellow.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 4 * scale) {
                        Text("GoFit")
                            .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(".Ai")
                            .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                    }
                    Text("Gamified Fitness • Free on App Store")
                        .font(.system(size: 10 * scale, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer().frame(height: size.height * 0.05)
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func achievementBadge(emoji: String, label: String) -> some View {
        VStack(spacing: 6 * scale) {
            Text(emoji)
                .font(.system(size: 28 * scale))
            Text(label)
                .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 14 * scale)
        .padding(.vertical, 12 * scale)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
    }
}


// ============================================================
// 6. CHALLENGE WIN STORY
// ============================================================
struct ChallengeWinStory: View {
    let data: StoryData
    let size: CGSize
    
    private var scale: CGFloat { size.width / 1080.0 }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.0, blue: 0.3),
                    Color(red: 0.5, green: 0.0, blue: 0.4),
                    Color(red: 0.3, green: 0.0, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Confetti particles
            ForEach(0..<20, id: \.self) { i in
                Text(["🎊", "🎉", "✨", "⭐️", "🏆"][i % 5])
                    .font(.system(size: CGFloat.random(in: 14...28) * scale))
                    .opacity(Double.random(in: 0.15...0.4))
                    .position(
                        x: CGFloat.random(in: 0...size.width),
                        y: CGFloat.random(in: 0...size.height)
                    )
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.1)
                
                Text("🏆")
                    .font(.system(size: 90 * scale))
                
                Text("CHALLENGE")
                    .font(.system(size: 40 * scale, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .kerning(4)
                
                Text("COMPLETED!")
                    .font(.system(size: 32 * scale, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.6))
                    .kerning(4)
                
                Spacer().frame(height: size.height * 0.06)
                
                // Challenge details
                VStack(spacing: 12 * scale) {
                    challengeRow(icon: "🎯", text: "Daily Challenge Crushed")
                    challengeRow(icon: "⚡", text: "+\(data.totalPoints) XP Earned")
                    challengeRow(icon: "🔥", text: "\(data.streakDays)-Day Streak Maintained")
                    challengeRow(icon: "💪", text: "Level \(data.level) \(data.levelTitle)")
                }
                .padding(20 * scale)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20 * scale, style: .continuous))
                .padding(.horizontal, 24 * scale)
                
                Spacer()
                
                // CTA + Branding
                VStack(spacing: 8 * scale) {
                    Text("Can you beat my score? 😏")
                        .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    if !data.referralCode.isEmpty {
                        Text("Code: \(data.referralCode)")
                            .font(.system(size: 14 * scale, weight: .bold, design: .monospaced))
                            .foregroundColor(.pink)
                            .padding(.horizontal, 16 * scale)
                            .padding(.vertical, 8 * scale)
                            .background(Color.pink.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 4 * scale) {
                        Text("GoFit")
                            .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(".Ai")
                            .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                    }
                    Text("Free on App Store")
                        .font(.system(size: 10 * scale, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer().frame(height: size.height * 0.05)
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func challengeRow(icon: String, text: String) -> some View {
        HStack(spacing: 12 * scale) {
            Text(icon)
                .font(.system(size: 22 * scale))
            Text(text)
                .font(.system(size: 16 * scale, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
        }
    }
}


// ============================================================
// 7. JOURNEY / TRANSFORMATION STORY
// ============================================================
struct JourneyStory: View {
    let data: StoryData
    let size: CGSize
    
    private var scale: CGFloat { size.width / 1080.0 }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color(red: 0.1, green: 0.05, blue: 0.2),
                    Color(red: 0.05, green: 0.05, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.08)
                
                Text("🌟")
                    .font(.system(size: 60 * scale))
                
                Text("MY FITNESS")
                    .font(.system(size: 36 * scale, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .kerning(4)
                
                Text("JOURNEY")
                    .font(.system(size: 28 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
                    .kerning(6)
                
                Spacer().frame(height: size.height * 0.05)
                
                // Timeline
                VStack(alignment: .leading, spacing: 0) {
                    timelineItem(
                        day: "Day 1",
                        title: "Started my journey",
                        subtitle: "Downloaded GoFit.Ai",
                        emoji: "🌱",
                        isFirst: true
                    )
                    timelineItem(
                        day: "Week 1",
                        title: "Built the habit",
                        subtitle: "7-day streak achieved!",
                        emoji: "🔥",
                        isFirst: false
                    )
                    timelineItem(
                        day: "Today",
                        title: "Level \(data.level) \(data.levelTitle)",
                        subtitle: "\(data.streakDays)-day streak • \(data.totalPoints) XP",
                        emoji: "🏆",
                        isFirst: false
                    )
                }
                .padding(.horizontal, 32 * scale)
                
                Spacer().frame(height: size.height * 0.05)
                
                // Highlight stats
                HStack(spacing: 12 * scale) {
                    journeyStat(value: "\(data.streakDays)", label: "Days", color: .orange)
                    journeyStat(value: "\(data.mealsLogged)", label: "Meals", color: .green)
                    journeyStat(value: "\(data.totalPoints)", label: "XP", color: .purple)
                }
                .padding(.horizontal, 32 * scale)
                
                Spacer()
                
                // Inspirational quote
                Text("\"The best project you'll ever work on is YOU\"")
                    .font(.system(size: 14 * scale, weight: .medium, design: .serif))
                    .foregroundColor(.white.opacity(0.6))
                    .italic()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40 * scale)
                
                Spacer().frame(height: size.height * 0.03)
                
                // Branding
                VStack(spacing: 6 * scale) {
                    if !data.referralCode.isEmpty {
                        Text("Start yours! Code: \(data.referralCode)")
                            .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16 * scale)
                            .padding(.vertical, 8 * scale)
                            .background(Color.purple.opacity(0.3))
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 4 * scale) {
                        Text("GoFit")
                            .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(".Ai")
                            .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                    }
                    Text("Free on App Store")
                        .font(.system(size: 10 * scale, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer().frame(height: size.height * 0.05)
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func timelineItem(day: String, title: String, subtitle: String, emoji: String, isFirst: Bool) -> some View {
        HStack(alignment: .top, spacing: 14 * scale) {
            // Timeline line + dot
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(Color.purple.opacity(0.4))
                        .frame(width: 2, height: 20 * scale)
                }
                
                Circle()
                    .fill(Color.purple)
                    .frame(width: 12 * scale, height: 12 * scale)
                
                Rectangle()
                    .fill(Color.purple.opacity(0.4))
                    .frame(width: 2, height: 20 * scale)
            }
            
            VStack(alignment: .leading, spacing: 2 * scale) {
                Text(day)
                    .font(.system(size: 10 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(.purple)
                
                HStack(spacing: 6 * scale) {
                    Text(emoji)
                        .font(.system(size: 18 * scale))
                    Text(title)
                        .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text(subtitle)
                    .font(.system(size: 12 * scale, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
    
    private func journeyStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4 * scale) {
            Text(value)
                .font(.system(size: 24 * scale, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11 * scale, weight: .medium, design: .rounded))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14 * scale)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
    }
}


// ============================================================
// 8. DAILY PROGRESS STORY
// ============================================================
struct DailyProgressStory: View {
    let data: StoryData
    let size: CGSize
    
    private var scale: CGFloat { size.width / 1080.0 }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.0, green: 0.1, blue: 0.2),
                    Color(red: 0.0, green: 0.25, blue: 0.4),
                    Color(red: 0.0, green: 0.15, blue: 0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.06)
                
                // Date header
                HStack {
                    VStack(alignment: .leading, spacing: 2 * scale) {
                        Text(Date().formatted(.dateTime.weekday(.wide)))
                            .font(.system(size: 14 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan.opacity(0.8))
                            .kerning(2)
                        Text(Date().formatted(.dateTime.day().month(.wide)))
                            .font(.system(size: 20 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    
                    // Streak badge
                    HStack(spacing: 4 * scale) {
                        Text("🔥")
                            .font(.system(size: 16 * scale))
                        Text("\(data.streakDays)")
                            .font(.system(size: 18 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12 * scale)
                    .padding(.vertical, 6 * scale)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 24 * scale)
                
                Spacer().frame(height: size.height * 0.03)
                
                // Greeting
                Text("Hey \(data.userName)! 👋")
                    .font(.system(size: 28 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Here's your daily progress")
                    .font(.system(size: 14 * scale, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer().frame(height: size.height * 0.04)
                
                // Big circular progress
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 10 * scale)
                        .frame(width: 160 * scale, height: 160 * scale)
                    
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10 * scale, lineCap: .round)
                        )
                        .frame(width: 160 * scale, height: 160 * scale)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2 * scale) {
                        Text("72%")
                            .font(.system(size: 36 * scale, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("COMPLETE")
                            .font(.system(size: 10 * scale, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                            .kerning(2)
                    }
                }
                
                Spacer().frame(height: size.height * 0.04)
                
                // Stats cards in 2x2 grid
                VStack(spacing: 10 * scale) {
                    HStack(spacing: 10 * scale) {
                        dailyStatCard(icon: "🔥", value: data.calories, label: "Calories", color: .orange)
                        dailyStatCard(icon: "👣", value: "\(data.steps.formatted())", label: "Steps", color: .green)
                    }
                    HStack(spacing: 10 * scale) {
                        dailyStatCard(icon: "💧", value: "\(String(format: "%.1f", data.waterIntake))L", label: "Water", color: .blue)
                        dailyStatCard(icon: "⚡", value: "\(Int(data.activeCalories))", label: "Active Cal", color: .yellow)
                    }
                }
                .padding(.horizontal, 24 * scale)
                
                Spacer()
                
                // Branding
                VStack(spacing: 6 * scale) {
                    if !data.referralCode.isEmpty {
                        Text("Track your health! Code: \(data.referralCode)")
                            .font(.system(size: 13 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 16 * scale)
                            .padding(.vertical, 8 * scale)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 4 * scale) {
                        Text("GoFit")
                            .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(".Ai")
                            .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                    }
                    Text("Your AI Health Companion • Free Download")
                        .font(.system(size: 10 * scale, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                
                Spacer().frame(height: size.height * 0.05)
            }
        }
        .frame(width: size.width, height: size.height)
    }
    
    private func dailyStatCard(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 10 * scale) {
            Text(icon)
                .font(.system(size: 24 * scale))
            
            VStack(alignment: .leading, spacing: 2 * scale) {
                Text(value)
                    .font(.system(size: 18 * scale, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 10 * scale, weight: .medium, design: .rounded))
                    .foregroundColor(color.opacity(0.8))
            }
            
            Spacer()
        }
        .padding(.horizontal, 14 * scale)
        .padding(.vertical, 12 * scale)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}


// ============================================================
// 9. AMBASSADOR / REFERRAL VIP STORY  ← NEW
// ============================================================
struct AmbassadorStory: View {
    let data: StoryData
    let tier: ReferralTier
    let size: CGSize

    private var scale: CGFloat { size.width / 1080.0 }

    var body: some View {
        ZStack {
            // PULSE aurora background
            Color(red: 0.031, green: 0.043, blue: 0.078)

            // Aurora blobs
            Ellipse()
                .fill(Color(red: 0.310, green: 0.275, blue: 0.898).opacity(0.35))
                .frame(width: size.width * 0.9, height: size.height * 0.45)
                .offset(x: -size.width * 0.12, y: -size.height * 0.22)
                .blur(radius: 70 * scale)

            Ellipse()
                .fill(Color(red: 0.486, green: 0.231, blue: 0.929).opacity(0.28))
                .frame(width: size.width * 0.7, height: size.height * 0.40)
                .offset(x: size.width * 0.15, y: size.height * 0.18)
                .blur(radius: 80 * scale)

            Ellipse()
                .fill(Color(red: 0.839, green: 0.290, blue: 0.682).opacity(0.18))
                .frame(width: size.width * 0.55, height: size.height * 0.30)
                .offset(x: -size.width * 0.20, y: size.height * 0.28)
                .blur(radius: 60 * scale)

            // Subtle dot grid
            Canvas { ctx, cSize in
                let spacing: CGFloat = 36 * scale
                for x in stride(from: 0, to: cSize.width, by: spacing) {
                    for y in stride(from: 0, to: cSize.height, by: spacing) {
                        let rect = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.06)))
                    }
                }
            }

            VStack(spacing: 0) {
                Spacer().frame(height: size.height * 0.07)

                // "Official Ambassador" badge
                HStack(spacing: 6 * scale) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11 * scale, weight: .black))
                        .foregroundStyle(Color(red: 0.310, green: 0.275, blue: 0.898))
                    Text("GOFIT.AI AMBASSADOR")
                        .font(.system(size: 11 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .kerning(1.5)
                }
                .padding(.horizontal, 16 * scale)
                .padding(.vertical, 8 * scale)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.09))
                        .overlay(Capsule().stroke(Color(red: 0.310, green: 0.275, blue: 0.898).opacity(0.5), lineWidth: 1))
                )

                Spacer().frame(height: size.height * 0.04)

                // Tier emoji + name
                VStack(spacing: 4 * scale) {
                    Text(tier.emoji)
                        .font(.system(size: 64 * scale))
                    Text(tier.name.uppercased() + " TIER")
                        .font(.system(size: 13 * scale, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: tier.gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .kerning(3)
                }

                Spacer().frame(height: size.height * 0.03)

                // Headline
                VStack(spacing: 6 * scale) {
                    Text("I use GoFit.Ai")
                        .font(.system(size: 28 * scale, weight: .bold, design: .default))
                        .foregroundStyle(Color.white.opacity(0.65))
                    Text("and you should too.")
                        .font(.system(size: 38 * scale, weight: .black, design: .default))
                        .foregroundStyle(.white)
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32 * scale)

                Spacer().frame(height: size.height * 0.04)

                // VIP Referral Code card
                VStack(spacing: 10 * scale) {
                    Text("USE MY EXCLUSIVE CODE")
                        .font(.system(size: 10 * scale, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.506, green: 0.545, blue: 0.973))
                        .kerning(2)

                    // Code display with dashed border
                    ZStack {
                        RoundedRectangle(cornerRadius: 16 * scale)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16 * scale)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color(red: 0.310, green: 0.275, blue: 0.898).opacity(0.6), Color(red: 0.486, green: 0.231, blue: 0.929).opacity(0.3)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [8 * scale, 4 * scale])
                                    )
                            )

                        HStack(spacing: 12 * scale) {
                            Spacer()
                            Text(data.referralCode.isEmpty ? "GOFIT" : data.referralCode)
                                .font(.system(size: 32 * scale, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .kerning(4)
                            Spacer()
                        }
                        .padding(.vertical, 18 * scale)
                    }
                    .padding(.horizontal, 28 * scale)

                    Text("Both of us get FREE XP when you sign up!")
                        .font(.system(size: 11 * scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))
                }

                Spacer().frame(height: size.height * 0.04)

                // Stats pill row
                HStack(spacing: 10 * scale) {
                    ambassadorStat(emoji: "🔥", value: "\(data.streakDays)d", label: "Streak")
                    ambassadorStat(emoji: "⚡", value: "\(data.totalPoints)", label: "XP")
                    ambassadorStat(emoji: "🏆", value: "Lv.\(data.level)", label: tier.name)
                }
                .padding(.horizontal, 28 * scale)

                Spacer()

                // Bottom brand bar
                VStack(spacing: 5 * scale) {
                    HStack(spacing: 0) {
                        Text("GoFit")
                            .font(.system(size: 22 * scale, weight: .black, design: .default))
                            .foregroundStyle(.white)
                        Text(".Ai")
                            .font(.system(size: 22 * scale, weight: .black, design: .default))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.310, green: 0.275, blue: 0.898), Color(red: 0.486, green: 0.231, blue: 0.929)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                    }
                    Text("AI-Powered Fitness · Free on App Store")
                        .font(.system(size: 10 * scale, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.35))
                }

                Spacer().frame(height: size.height * 0.06)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func ambassadorStat(emoji: String, value: String, label: String) -> some View {
        VStack(spacing: 3 * scale) {
            Text(emoji).font(.system(size: 18 * scale))
            Text(value)
                .font(.system(size: 16 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12 * scale)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale))
        .overlay(
            RoundedRectangle(cornerRadius: 14 * scale)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
}
