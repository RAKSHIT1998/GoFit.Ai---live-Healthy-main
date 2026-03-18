import SwiftUI

struct HomeDashboardView: View {

    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var purchases: PurchaseManager
    @StateObject private var healthKit = HealthKitService.shared
    @ObservedObject private var streakManager = StreakManager.shared
    @ObservedObject private var fastingModel = FastingTimerModel.shared
    @State private var showingSleepTracker = false

    @State private var showingScanner = false
    @State private var showingHistory = false
    @State private var showingFasting = false
    @State private var showingWorkout = false
    @State private var showingLiquidLog = false
    @State private var showingShareProgress = false
    @State private var showCelebration = false
    @State private var celebrationMessage = ""

    @State private var todayCalories = "—"
    @State private var todayProtein = "—"
    @State private var todayCarbs = "—"
    @State private var todayFat = "—"
    @State private var todaySugar: Double = 0
    @State private var todayCaloriesValue: Double = 0
    @State private var todayProteinValue: Double = 0
    @State private var todayCarbsValue: Double = 0
    @State private var todayFatValue: Double = 0
    @State private var todaySugarValue: Double = 0

    @State private var fastingStatus = "Not fasting"
    @State private var waterIntake: Double = 0
    @State private var liquidIntakeGoal: Double = AppConstants.defaultWaterGoal
    
    // AI-calculated target calories from onboarding
    @State private var targetCalories: Int? = nil

    @State private var isLoading = false
    @State private var animateCards = false
    
    // Inline AI Recommendations
    @State private var aiRecommendation: RecommendationResponse?
    @State private var aiRecommendationLoading = false
    @State private var isUsingFallback = true

    var body: some View {
        NavigationView {
            ZStack {
                Design.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.lg) {
                        
                        // ━━━ SECTION 1: Welcome & Core Stats ━━━
                        enhancedWelcomeHeader
                            .delayedAppear(0)
                        
                        mainStatsCard
                            .delayedAppear(0.04)
                        
                        quickActionsSection
                            .delayedAppear(0.08)
                        
                        // ━━━ SECTION 2: Social & Friends ━━━
                        SocialActivityCard()
                            .delayedAppear(0.12)
                        
                        FriendsLeaderboardCard()
                            .delayedAppear(0.16)
                        
                        // ━━━ SECTION 3: Gamification ━━━
                        StreakCard()
                            .delayedAppear(0.20)
                        
                        DailyChallengeCard()
                            .delayedAppear(0.24)
                        
                        // ━━━ SECTION 4: Health Tracking ━━━
                        compactActivityHighlights
                            .delayedAppear(0.28)
                        
                        fastingCard
                            .delayedAppear(0.32)
                        
                        waterIntakeCard
                            .delayedAppear(0.36)
                        
                        // ━━━ SECTION 5: AI Coaching ━━━
                        aiWorkoutSection
                            .delayedAppear(0.40)
                        
                        aiMealSection
                            .delayedAppear(0.44)
                        
                        // ━━━ SECTION 6: Share & Grow ━━━
                        ShareYourStoryCard()
                            .delayedAppear(0.48)
                        
                        ReferAndEarnCard()
                            .delayedAppear(0.52)
                    }
                    .padding(.horizontal, Design.Spacing.md)
                    .padding(.bottom, Design.Spacing.xl)
                }
                .overlay(alignment: .bottomTrailing) {
                    instantQuickLogButtons
                }
                .refreshable {
                    HapticManager.shared.lightTap()
                    await loadLiquidIntakeGoal()
                    await loadSummary()
                    await loadWaterIntake()
                    await loadHealthData()
                    await loadInlineRecommendations()
                    // Always try reading — user may have granted read access
                    await healthKit.readTodayData()
                    try? await healthKit.syncToBackend()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.shared.lightTap()
                        showingHistory = true
                    } label: {
                        Image(systemName: "clock.fill")
                            .foregroundColor(Design.Colors.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            HapticManager.shared.lightTap()
                            showingFasting = true
                        } label: {
                            Label("Fasting", systemImage: "timer")
                        }
                        Button {
                            HapticManager.shared.lightTap()
                            showingShareProgress = true
                        } label: {
                            Label("Share Progress", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundColor(Design.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showingScanner) {
                MealScannerView3().environmentObject(auth)
            }
            .sheet(isPresented: $showingHistory) {
                DailyLogHistoryView().environmentObject(auth)
            }
            .sheet(isPresented: $showingFasting) {
                FastingView()
            }
            .sheet(isPresented: $showingSleepTracker) {
                SleepTrackerView()
            }
            .sheet(isPresented: $showingWorkout) {
                WorkoutSuggestionsView().environmentObject(auth)
            }
            .sheet(isPresented: $showingLiquidLog) {
                LiquidLogView()
                    .environmentObject(auth)
                    .onDisappear {
                        Task {
                            await loadWaterIntake()
                        }
                    }
            }
            .sheet(isPresented: $showingShareProgress) {
                ShareProgressView(
                    calories: todayCalories,
                    steps: healthKit.todaySteps,
                    activeCalories: healthKit.todayActiveCalories,
                    waterIntake: waterIntake,
                    heartRate: healthKit.restingHeartRate > 0 ? healthKit.restingHeartRate : nil
                )
                .environmentObject(auth)
            }
            .onAppear {
                withAnimation(Design.Animation.spring) {
                    animateCards = true
                }

                Task(priority: .userInitiated) {
                    async let targetCalories: Void = loadTargetCalories()
                    async let liquidGoal: Void = loadLiquidIntakeGoal()
                    async let summary: Void = loadSummary()
                    async let water: Void = loadWaterIntake()
                    async let backendHealth: Void = loadHealthData()

                    _ = await (targetCalories, liquidGoal, summary, water, backendHealth)

                    await syncHealthData()
                    
                    // Populate daily challenges with current data
                    let mealCount = Double(LocalMealCache.shared.getTodayMeals().count)
                    let totals = LocalMealCache.shared.getTodayTotals()
                    DailyChallengeManager.shared.updateProgress(for: .meals, value: mealCount)
                    DailyChallengeManager.shared.updateProgress(for: .protein, value: totals.protein)
                    
                    // Load inline AI recommendations
                    await loadInlineRecommendations()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("MealSaved"))) { _ in
                Task {
                    let localTotals = LocalMealCache.shared.getTodayTotals()
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            todayCalories = "\(Int(localTotals.calories))"
                            todayProtein = "\(Int(localTotals.protein))g"
                            todayCarbs = "\(Int(localTotals.carbs))g"
                            todayFat = "\(Int(localTotals.fat))g"
                            todaySugar = localTotals.sugar
                            todayCaloriesValue = localTotals.calories
                            todayProteinValue = localTotals.protein
                            todayCarbsValue = localTotals.carbs
                            todayFatValue = localTotals.fat
                            todaySugarValue = localTotals.sugar
                        }
                        HapticManager.shared.lightTap()
                        
                        // Award points for logging a meal
                        streakManager.logMeal()
                        
                        // Update daily challenge progress for meals + protein
                        let mealCount = Double(LocalMealCache.shared.getTodayMeals().count)
                        DailyChallengeManager.shared.updateProgress(for: .meals, value: mealCount)
                        DailyChallengeManager.shared.updateProgress(for: .protein, value: localTotals.protein)
                        
                        // Check water goal for bonus XP
                        if waterIntake >= liquidIntakeGoal && liquidIntakeGoal > 0 {
                            RewardEngine.shared.rewardWaterGoal()
                        }
                    }
                    syncWatchMetrics(
                        calories: localTotals.calories,
                        protein: localTotals.protein,
                        carbs: localTotals.carbs,
                        fat: localTotals.fat,
                        sugar: localTotals.sugar,
                        water: waterIntake
                    )
                    await loadSummary()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openMealScannerFromWatch)) { _ in
                showingScanner = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .openWaterLogFromWatch)) { _ in
                showingLiquidLog = true
            }
            .celebration(isShowing: $showCelebration, message: celebrationMessage)
        }
    }

    // MARK: - Welcome Header (Clean White Design)
    private var welcomeHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back,")
                    .font(Design.Typography.subheadline)
                    .foregroundColor(.secondary)

                Text(auth.name.isEmpty ? "User" : auth.name)
                    .font(Design.Typography.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
        .padding(.vertical, Design.Spacing.sm)
    }
    
    // MARK: - Enhanced Welcome Header with Mascot
    private var enhancedWelcomeHeader: some View {
        VStack(spacing: Design.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timeBasedGreeting())
                        .font(Design.Typography.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(auth.name.isEmpty ? "User" : auth.name)
                            .font(Design.Typography.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        // Streak fire badge
                        if streakManager.currentStreak > 0 {
                            HStack(spacing: 3) {
                                Text(streakManager.streakEmoji)
                                    .font(.system(size: 14))
                                Text("\(streakManager.currentStreak)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
                
                // Mini mascot
                MiniMascot(level: streakManager.level)
            }
            
            // Dynamic sub-message based on time & progress
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundColor(Design.Colors.primary)
                Text(dynamicMotivation())
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding(.vertical, Design.Spacing.sm)
    }
    
    // MARK: - Time-Based Greeting
    private func timeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9: return "Good morning! ☀️ Rise & grind,"
        case 9..<12: return "Hey there! 💪 Keep crushing it,"
        case 12..<14: return "Lunch time! 🍱 Fuel up,"
        case 14..<17: return "Good afternoon! ⚡️ Stay strong,"
        case 17..<20: return "Evening vibes! 🌅 Great work today,"
        case 20..<23: return "Night mode! 🌙 Winding down,"
        default: return "Burning the midnight oil? 🦉 Hey,"
        }
    }
    
    // MARK: - Dynamic Motivation
    private func dynamicMotivation() -> String {
        if streakManager.currentStreak >= 30 {
            return "🔥 \(streakManager.currentStreak)-day streak! You're a fitness LEGEND!"
        } else if streakManager.currentStreak >= 7 {
            return "⚡️ \(streakManager.currentStreak)-day streak! Unstoppable energy!"
        } else if streakManager.todayPoints > 50 {
            return "🎯 \(streakManager.todayPoints) XP earned today! Keep going!"
        } else if todayCalories != "—" && todayCalories != "0" {
            return "🍏 \(todayCalories) kcal logged today. Nice tracking!"
        } else {
            let messages = [
                "Ready to make today count? Let's go! 🚀",
                "Your fitness journey continues! 🌟",
                "Small steps, big results! 💫",
                "Today is your day to shine! ✨"
            ]
            let dayIndex = Calendar.current.component(.day, from: Date())
            return messages[dayIndex % messages.count]
        }
    }

    // MARK: - Main Stats (Circular Meter Cluster)
    private var mainStatsCard: some View {
        VStack(spacing: Design.Spacing.lg) {
            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Today's Nutrition")
                            .font(Design.Typography.headline)
                            .foregroundColor(.primary)
                        
                        if targetCalories != nil {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                                .foregroundColor(Design.Colors.primary)
                        }
                    }
                }
                
                Spacer()
                
                // Share Button
                Button {
                    showingShareProgress = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundColor(Design.Colors.primary)
                }
            }
            
            // Central calorie ring + burned
            HStack(spacing: Design.Spacing.lg) {
                // Main calorie circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.12), lineWidth: 14)
                    
                    let calorieProgress: Double = {
                        guard let target = targetCalories, target > 0,
                              todayCalories != "—",
                              let current = Int(todayCalories) else { return 0 }
                        return min(Double(current) / Double(target), 1.0)
                    }()
                    
                    Circle()
                        .trim(from: 0, to: calorieProgress)
                        .stroke(
                            AngularGradient(
                                colors: [Design.Colors.calories, Design.Colors.calories.opacity(0.6)],
                                center: .center,
                                angle: .degrees(-90)
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(Design.Animation.smooth, value: calorieProgress)
                    
                    VStack(spacing: 2) {
                        Text(todayCalories)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        if let target = targetCalories {
                            Text("/ \(target)")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        Text("kcal")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Design.Colors.calories)
                    }
                }
                .frame(width: 130, height: 130)
                
                // Burned + macro summary
                VStack(alignment: .leading, spacing: Design.Spacing.md) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(Design.Colors.steps)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(Int(healthKit.todayActiveCalories))")
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(Design.Colors.steps)
                            Text("Burned")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    let calorieProgress: Double = {
                        guard let target = targetCalories, target > 0,
                              todayCalories != "—",
                              let current = Int(todayCalories) else { return 0 }
                        return min(Double(current) / Double(target), 1.0)
                    }()
                    
                    Text("\(Int(calorieProgress * 100))% of goal")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(calorieProgress >= 1.0 ? Design.Colors.sugar : Design.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (calorieProgress >= 1.0 ? Design.Colors.sugar : Design.Colors.primary).opacity(0.1)
                        )
                        .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Macro Rings Cluster
            HStack(spacing: Design.Spacing.sm) {
                macroRing(
                    value: todayProteinValue,
                    maxValue: 120,
                    label: "Protein",
                    display: todayProtein,
                    color: Design.Colors.protein
                )
                
                macroRing(
                    value: todayCarbsValue,
                    maxValue: 250,
                    label: "Carbs",
                    display: todayCarbs,
                    color: Design.Colors.carbs
                )
                
                macroRing(
                    value: todayFatValue,
                    maxValue: 80,
                    label: "Fat",
                    display: todayFat,
                    color: Design.Colors.fat
                )
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
    
    private func macroRing(value: Double, maxValue: Double, label: String, display: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.12), lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: maxValue > 0 ? min(value / maxValue, 1.0) : 0)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(Design.Animation.smooth, value: value)
                
                VStack(spacing: 0) {
                    Text(display)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }
            }
            .frame(width: 70, height: 70)
            
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    

    // MARK: - Quick Actions (Clean White Design)
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Text("Quick Actions")
                .font(Design.Typography.headline)
                .foregroundColor(.primary)

            HStack(spacing: Design.Spacing.md) {
                // Scan Meal Button - Opens Camera
                Button {
                    HapticManager.shared.mediumTap()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingScanner = true
                    }
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Design.Colors.primary)
                            .clipShape(Circle())
                        
                        Text("Scan Meal")
                            .font(Design.Typography.caption)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.md)
                    .background(Design.Colors.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(SmoothButtonStyle())

                Button {
                    HapticManager.shared.mediumTap()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingLiquidLog = true
                    }
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "drop.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Design.Colors.water)
                            .clipShape(Circle())
                        
                        Text("Liquid")
                            .font(Design.Typography.caption)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.md)
                    .background(Design.Colors.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(SmoothButtonStyle())

                Button {
                    HapticManager.shared.mediumTap()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingWorkout = true
                    }
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.walk")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Design.Colors.steps)
                            .clipShape(Circle())
                        
                        Text("Workout")
                            .font(Design.Typography.caption)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.md)
                    .background(Design.Colors.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(SmoothButtonStyle())
            }
            
            // Second row: Fasting + Sleep
            HStack(spacing: Design.Spacing.md) {
                Button {
                    HapticManager.shared.mediumTap()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingFasting = true
                    }
                } label: {
                    VStack(spacing: 12) {
                        ZStack {
                            Image(systemName: "timer")
                                .font(.title)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                            
                            if fastingModel.isFasting {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 14, height: 14)
                                    .overlay(
                                        Circle().stroke(Design.Colors.cardBackground, lineWidth: 2)
                                    )
                                    .offset(x: 20, y: -20)
                            }
                        }
                        
                        Text("Fasting")
                            .font(Design.Typography.caption)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.md)
                    .background(Design.Colors.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(SmoothButtonStyle())
                
                Button {
                    HapticManager.shared.mediumTap()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingSleepTracker = true
                    }
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "moon.stars.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                LinearGradient(
                                    colors: [.purple, .indigo],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                        
                        Text("Sleep")
                            .font(Design.Typography.caption)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.md)
                    .background(Design.Colors.cardBackground)
                    .cornerRadius(16)
                    .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(SmoothButtonStyle())
            }
        }
    }

    // MARK: - Health Metrics (Clean White Design)
    private var healthMetricsSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Text("Today's Activity")
                .font(Design.Typography.headline)
                .foregroundColor(.primary)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: Design.Spacing.md),
                GridItem(.flexible(), spacing: Design.Spacing.md),
                GridItem(.flexible(), spacing: Design.Spacing.md)
            ], spacing: Design.Spacing.md) {
                activityMetricCard(icon: "figure.walk", value: "\(healthKit.todaySteps)", label: "Steps", color: Design.Colors.steps)
                activityMetricCard(icon: "flame.fill", value: "\(Int(healthKit.todayActiveCalories))", label: "Active Cal", color: Design.Colors.calories)
                activityMetricCard(icon: "bolt.heart.fill", value: "\(Int(healthKit.todayRestingCalories))", label: "Resting Cal", color: .orange)

                activityMetricCard(icon: "figure.walk.motion", value: healthKit.todayWalkingRunningDistance > 0 ? String(format: "%.1f km", healthKit.todayWalkingRunningDistance) : "—", label: "Walk/Run", color: .green)
                activityMetricCard(icon: "bicycle", value: healthKit.todayCyclingDistance > 0 ? String(format: "%.1f km", healthKit.todayCyclingDistance) : "—", label: "Cycling", color: .mint)
                activityMetricCard(icon: "stairs", value: "\(healthKit.todayFlightsClimbed)", label: "Flights", color: .indigo)

                activityMetricCard(icon: "bed.double.fill", value: healthKit.sleepHours > 0 ? String(format: "%.1f h", healthKit.sleepHours) : "—", label: "Sleep", color: .purple)
                activityMetricCard(icon: "heart.fill", value: healthKit.restingHeartRate > 0 ? "\(Int(healthKit.restingHeartRate))" : "—", label: "Rest HR", color: Design.Colors.heart)
                activityMetricCard(icon: "waveform.path.ecg", value: healthKit.heartRateVariability > 0 ? "\(Int(healthKit.heartRateVariability))" : "—", label: "HRV", color: .pink)

                activityMetricCard(icon: "lungs.fill", value: healthKit.respiratoryRate > 0 ? String(format: "%.1f", healthKit.respiratoryRate) : "—", label: "Resp", color: .teal)
                activityMetricCard(icon: "drop.fill", value: healthKit.bloodOxygen > 0 ? String(format: "%.0f%%", healthKit.bloodOxygen) : "—", label: "SpO₂", color: .blue)
                activityMetricCard(icon: "brain.head.profile", value: healthKit.mindfulMinutes > 0 ? "\(Int(healthKit.mindfulMinutes))m" : "—", label: "Mindful", color: .cyan)
            }
        }
    }

    private func activityMetricCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            Text(value)
                .font(Design.Typography.caption)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(Design.Typography.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Design.Spacing.md)
        .padding(.horizontal, 6)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    // MARK: - Compact Activity Highlights (replaces 12-metric grid)
    private var compactActivityHighlights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Activity")
                .font(Design.Typography.headline)
                .foregroundColor(.primary)
            
            // Top row: 4 key metrics
            HStack(spacing: 10) {
                compactMetric(
                    icon: "figure.walk",
                    value: "\(healthKit.todaySteps)",
                    label: "Steps",
                    color: Design.Colors.steps
                )
                compactMetric(
                    icon: "flame.fill",
                    value: "\(Int(healthKit.todayActiveCalories))",
                    label: "Active Cal",
                    color: Design.Colors.calories
                )
                compactMetric(
                    icon: "heart.fill",
                    value: healthKit.restingHeartRate > 0 ? "\(Int(healthKit.restingHeartRate))" : "—",
                    label: "Heart Rate",
                    color: Design.Colors.heart
                )
                compactMetric(
                    icon: "bed.double.fill",
                    value: healthKit.sleepHours > 0 ? String(format: "%.1fh", healthKit.sleepHours) : "—",
                    label: "Sleep",
                    color: .purple
                )
            }
            
            // Bottom row: 4 secondary metrics
            HStack(spacing: 10) {
                compactMetric(
                    icon: "figure.walk.motion",
                    value: healthKit.todayWalkingRunningDistance > 0 ? String(format: "%.1f km", healthKit.todayWalkingRunningDistance) : "—",
                    label: "Distance",
                    color: .green
                )
                compactMetric(
                    icon: "stairs",
                    value: "\(healthKit.todayFlightsClimbed)",
                    label: "Flights",
                    color: .indigo
                )
                compactMetric(
                    icon: "drop.fill",
                    value: healthKit.bloodOxygen > 0 ? String(format: "%.0f%%", healthKit.bloodOxygen) : "—",
                    label: "SpO₂",
                    color: .blue
                )
                compactMetric(
                    icon: "waveform.path.ecg",
                    value: healthKit.heartRateVariability > 0 ? "\(Int(healthKit.heartRateVariability))" : "—",
                    label: "HRV",
                    color: .pink
                )
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
    
    private func compactMetric(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.06))
        .cornerRadius(12)
    }

    // MARK: - Water & Blood Sugar Meter Cluster (Circular)
    private var waterIntakeCard: some View {
        HStack(spacing: Design.Spacing.md) {
            // Water Ring
            Button {
                HapticManager.shared.lightTap()
                showingLiquidLog = true
            } label: {
                VStack(spacing: Design.Spacing.sm) {
                    let waterProgress: Double = {
                        guard liquidIntakeGoal > 0,
                              waterIntake.isFinite,
                              !waterIntake.isNaN else {
                            return 0.0
                        }
                        return min(waterIntake / liquidIntakeGoal, 1.0)
                    }()
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.12), lineWidth: 10)
                        
                        Circle()
                            .trim(from: 0, to: waterProgress)
                            .stroke(
                                AngularGradient(
                                    colors: [Design.Colors.water, Design.Colors.water.opacity(0.5)],
                                    center: .center,
                                    angle: .degrees(-90)
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(Design.Animation.smooth, value: waterProgress)
                        
                        VStack(spacing: 2) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Design.Colors.water)
                            Text("\(String(format: "%.1f", waterIntake))L")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("\(Int(waterProgress * 100))%")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(Design.Colors.water)
                        }
                    }
                    .frame(width: 110, height: 110)
                    
                    Text("Water")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Goal: \(String(format: "%.1f", liquidIntakeGoal))L")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Design.Spacing.md)
                .background(Design.Colors.cardBackground)
                .cornerRadius(16)
                .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            // Blood Sugar Ring
            VStack(spacing: Design.Spacing.sm) {
                let sugarProgress: Double = {
                    guard AppConstants.defaultSugarGoal > 0,
                          todaySugar.isFinite,
                          !todaySugar.isNaN else {
                        return 0.0
                    }
                    return min(todaySugar / AppConstants.defaultSugarGoal, 1.0)
                }()
                
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.12), lineWidth: 10)
                    
                    Circle()
                        .trim(from: 0, to: sugarProgress)
                        .stroke(
                            AngularGradient(
                                colors: [Design.Colors.sugar, Design.Colors.sugar.opacity(0.5)],
                                center: .center,
                                angle: .degrees(-90)
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(Design.Animation.smooth, value: sugarProgress)
                    
                    VStack(spacing: 2) {
                        Image(systemName: "drop.halffull")
                            .font(.system(size: 16))
                            .foregroundColor(Design.Colors.sugar)
                        Text("\(String(format: "%.1f", todaySugar))g")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("\(Int(sugarProgress * 100))%")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Design.Colors.sugar)
                    }
                }
                .frame(width: 110, height: 110)
                
                Text("Blood Sugar")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Goal: \(String(format: "%.0f", AppConstants.defaultSugarGoal))g")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(Design.Spacing.md)
            .background(Design.Colors.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Fasting Card (Prominent Inline)
    private var fastingCard: some View {
        Button {
            HapticManager.shared.lightTap()
            showingFasting = true
        } label: {
            VStack(alignment: .leading, spacing: Design.Spacing.md) {
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.2), .red.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "timer")
                                .font(.system(size: 18))
                                .foregroundColor(.orange)
                        }
                        
                        Text("Intermittent Fasting")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if fastingModel.isFasting {
                        Text("Active")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(8)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if fastingModel.isFasting {
                    // Active fasting state
                    HStack(spacing: Design.Spacing.lg) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fastingModel.remainingString)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(fastingModel.elapsedString)
                                .font(.headline)
                                .foregroundColor(Design.Colors.primary)
                            Text("elapsed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.gray.opacity(0.15))
                                .frame(height: 10)
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, Design.Colors.primary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * fastingModel.progress, height: 10)
                                .animation(.easeInOut(duration: 0.3), value: fastingModel.progress)
                        }
                    }
                    .frame(height: 10)
                    
                    HStack {
                        Text("\(fastingModel.fastingWindowHours):\(24 - fastingModel.fastingWindowHours) window")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(fastingModel.progress * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                } else {
                    // Not fasting — quick start options
                    HStack(spacing: Design.Spacing.md) {
                        ForEach([("16:8", 16), ("18:6", 18), ("20:4", 20)], id: \.0) { label, hours in
                            Button {
                                HapticManager.shared.mediumTap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    fastingModel.startFast(hours: hours)
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text("\(hours)h")
                                        .font(.headline)
                                        .foregroundColor(Design.Colors.primary)
                                    Text(label)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Design.Colors.primary.opacity(0.08))
                                .cornerRadius(12)
                            }
                        }
                    }
                    
                    if fastingModel.streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("\(fastingModel.streak) day streak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(fastingModel.completedFasts) fasts completed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(Design.Spacing.lg)
            .background(Design.Colors.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if fastingModel.isFasting {
                fastingModel.updateTimer()
            }
        }
    }
    
    // MARK: - Inline AI Workout Section
    private var aiWorkoutSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(Design.Colors.steps)
                    .font(.title3)
                Text("Today's Workouts")
                    .font(Design.Typography.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isUsingFallback {
                    Text("Built-in")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("AI")
                            .font(.caption2)
                    }
                    .foregroundColor(Design.Colors.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Design.Colors.primary.opacity(0.1))
                    .cornerRadius(4)
                }
                
                Button {
                    HapticManager.shared.lightTap()
                    showingWorkout = true
                } label: {
                    Text("See All")
                        .font(Design.Typography.caption)
                        .foregroundColor(Design.Colors.primary)
                }
            }
            
            if aiRecommendationLoading && aiRecommendation == nil {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading workouts...")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(Design.Spacing.lg)
            } else if let rec = aiRecommendation, !rec.workoutPlan.exercises.isEmpty {
                ForEach(Array(rec.workoutPlan.exercises.prefix(3).enumerated()), id: \.offset) { index, exercise in
                    Button {
                        HapticManager.shared.lightTap()
                        showingWorkout = true
                    } label: {
                        HStack(spacing: Design.Spacing.md) {
                            ZStack {
                                Circle()
                                    .fill(Design.Colors.primaryGradient)
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: RecommendationVisualService.shared.getExerciseIcon(for: exercise.name))
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(Design.Typography.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                HStack(spacing: Design.Spacing.sm) {
                                    Label("\(exercise.duration) min", systemImage: "clock.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Label("\(exercise.calories) kcal", systemImage: "flame.fill")
                                        .font(.caption2)
                                        .foregroundColor(Design.Colors.calories)
                                    
                                    if let difficulty = exercise.difficulty {
                                        Text(difficulty.capitalized)
                                            .font(.caption2)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(workoutDifficultyColor(difficulty).opacity(0.2))
                                            .foregroundColor(workoutDifficultyColor(difficulty))
                                            .cornerRadius(4)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(Design.Spacing.sm)
                    }
                    
                    if index < min(rec.workoutPlan.exercises.count, 3) - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
                
                if rec.workoutPlan.exercises.count > 3 {
                    Button {
                        HapticManager.shared.lightTap()
                        showingWorkout = true
                    } label: {
                        Text("+ \(rec.workoutPlan.exercises.count - 3) more exercises")
                            .font(Design.Typography.caption)
                            .foregroundColor(Design.Colors.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                    }
                }
            } else {
                VStack(spacing: Design.Spacing.sm) {
                    Image(systemName: "figure.run")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Tap to get workout suggestions")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Design.Spacing.md)
                .onTapGesture {
                    HapticManager.shared.lightTap()
                    showingWorkout = true
                }
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
    
    // MARK: - Inline AI Meal Section
    private var aiMealSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(Design.Colors.calories)
                    .font(.title3)
                Text("What to Eat Today")
                    .font(Design.Typography.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isUsingFallback {
                    Text("Built-in")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("AI")
                            .font(.caption2)
                    }
                    .foregroundColor(Design.Colors.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Design.Colors.primary.opacity(0.1))
                    .cornerRadius(4)
                }
                
                Button {
                    HapticManager.shared.lightTap()
                    showingWorkout = true
                } label: {
                    Text("See All")
                        .font(Design.Typography.caption)
                        .foregroundColor(Design.Colors.primary)
                }
            }
            
            if aiRecommendationLoading && aiRecommendation == nil {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading meal plan...")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(Design.Spacing.lg)
            } else if let rec = aiRecommendation {
                let allMeals: [(String, String, [RecommendationMealItem])] = [
                    ("Breakfast", "sunrise.fill", rec.mealPlan.breakfast),
                    ("Lunch", "sun.max.fill", rec.mealPlan.lunch),
                    ("Dinner", "moon.fill", rec.mealPlan.dinner),
                    ("Snacks", "leaf.fill", rec.mealPlan.snacks)
                ].filter { !$0.2.isEmpty }
                
                if allMeals.isEmpty {
                    VStack(spacing: Design.Spacing.sm) {
                        Image(systemName: "fork.knife")
                            .font(.title2)
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("Tap to get meal suggestions")
                            .font(Design.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Design.Spacing.md)
                    .onTapGesture {
                        HapticManager.shared.lightTap()
                        showingWorkout = true
                    }
                } else {
                    ForEach(Array(allMeals.enumerated()), id: \.offset) { index, mealGroup in
                        let (title, icon, meals) = mealGroup
                        
                        Button {
                            HapticManager.shared.lightTap()
                            showingWorkout = true
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Image(systemName: icon)
                                        .foregroundColor(Design.Colors.primary)
                                        .font(.subheadline)
                                    Text(title)
                                        .font(Design.Typography.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    
                                    let totalCals = meals.reduce(0) { $0 + Int($1.calories) }
                                    Text("\(totalCals) kcal")
                                        .font(.caption)
                                        .foregroundColor(Design.Colors.calories)
                                        .fontWeight(.medium)
                                }
                                
                                ForEach(meals.prefix(2)) { meal in
                                    HStack(spacing: Design.Spacing.sm) {
                                        Circle()
                                            .fill(Design.Colors.primary.opacity(0.3))
                                            .frame(width: 6, height: 6)
                                        
                                        Text(meal.name)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Text("\(Int(meal.calories)) kcal")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.leading, 20)
                                }
                                
                                if meals.count > 2 {
                                    Text("+ \(meals.count - 2) more")
                                        .font(.caption2)
                                        .foregroundColor(Design.Colors.primary)
                                        .padding(.leading, 20)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        
                        if index < allMeals.count - 1 {
                            Divider()
                        }
                    }
                }
            } else {
                VStack(spacing: Design.Spacing.sm) {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Tap to get meal suggestions")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Design.Spacing.md)
                .onTapGesture {
                    HapticManager.shared.lightTap()
                    showingWorkout = true
                }
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
    
    private func workoutDifficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy", "beginner": return .green
        case "medium", "moderate", "intermediate": return .orange
        case "hard", "advanced", "expert": return .red
        default: return .secondary
        }
    }
    
    // MARK: - AI Recommendations (Clean White Design)
    private var aiRecommendationsCard: some View {
        Button {
            showingWorkout = true
        } label: {
            HStack(spacing: Design.Spacing.md) {
                Image(systemName: "sparkles")
                    .foregroundColor(.white)
                    .font(.title3)
                    .frame(width: 50, height: 50)
                    .background(Design.Colors.primary)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Recommendations")
                        .font(Design.Typography.headline)
                        .foregroundColor(.primary)

                    Text("Personalized meals & workouts")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(Design.Spacing.lg)
            .background(Design.Colors.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
    }

    // MARK: - Data
    
    // Load AI-calculated target calories from user profile
    private func loadTargetCalories() async {
        guard auth.isLoggedIn else {
            return
        }
        
        guard let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty else {
            return
        }
        
        do {
            struct UserProfile: Codable {
                let id: String
                let name: String
                let email: String
                let metrics: Metrics?
            }
            
            struct Metrics: Codable {
                let targetCalories: Int?
            }
            
            let profile: UserProfile = try await NetworkManager.shared.request(
                "auth/me",
                method: "GET",
                body: nil
            )
            
            await MainActor.run {
                targetCalories = profile.metrics?.targetCalories
                if let target = targetCalories {
                    print("✅ Loaded AI-calculated target calories: \(target) kcal")
                } else {
                    print("⚠️ No target calories found in user profile")
                }
            }
        } catch {
            print("⚠️ Failed to load target calories: \(error.localizedDescription)")
        }
    }
    
    private func loadSummary() async {
        // Check if user is logged in
        guard auth.isLoggedIn else {
            print("⚠️ Cannot load summary: User not logged in")
            return
        }
        
        // FIRST: Load from local cache immediately for instant UI
        let localTotals = LocalMealCache.shared.getTodayTotals()
        await MainActor.run {
            todayCalories = "\(Int(localTotals.calories))"
            todayProtein = "\(Int(localTotals.protein))g"
            todayCarbs = "\(Int(localTotals.carbs))g"
            todayFat = "\(Int(localTotals.fat))g"
            todaySugar = localTotals.sugar
            todayCaloriesValue = localTotals.calories
            todayProteinValue = localTotals.protein
            todayCarbsValue = localTotals.carbs
            todayFatValue = localTotals.fat
            todaySugarValue = localTotals.sugar
        }
        syncWatchMetrics(
            calories: localTotals.calories,
            protein: localTotals.protein,
            carbs: localTotals.carbs,
            fat: localTotals.fat,
            sugar: localTotals.sugar,
            water: waterIntake
        )
        print("✅ Loaded from local cache: \(Int(localTotals.calories)) kcal")
        
        // THEN: Sync with backend in background (non-blocking)
        guard let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty else {
            print("⚠️ No valid token, using local cache only")
            return
        }
        
        isLoading = true
        defer { isLoading = false }

        do {
            struct Summary: Codable {
                let calories: Double
                let protein: Double
                let carbs: Double
                let fat: Double
                let sugar: Double?
            }

            // Force fresh fetch by adding timestamp to prevent caching
            let endpoint = "meals/summary/today?t=\(Date().timeIntervalSince1970)"
            let summary: Summary =
                try await NetworkManager.shared.request(
                    endpoint,
                    method: "GET",
                    body: nil
                )

            // Validate and sanitize values to prevent NaN
            let calories = summary.calories.isFinite && !summary.calories.isNaN ? summary.calories : 0
            let protein = summary.protein.isFinite && !summary.protein.isNaN ? summary.protein : 0
            let carbs = summary.carbs.isFinite && !summary.carbs.isNaN ? summary.carbs : 0
            let fat = summary.fat.isFinite && !summary.fat.isNaN ? summary.fat : 0
            let sugar = (summary.sugar ?? 0).isFinite && !(summary.sugar ?? 0).isNaN ? (summary.sugar ?? 0) : 0

            // Update UI with the higher of local vs backend data (prevents zeroing out)
            let mergedCals = max(calories, localTotals.calories)
            let mergedProtein = max(protein, localTotals.protein)
            let mergedCarbs = max(carbs, localTotals.carbs)
            let mergedFat = max(fat, localTotals.fat)
            let mergedSugar = max(sugar, localTotals.sugar)
            
            await MainActor.run {
                todayCalories = "\(Int(mergedCals))"
                todayProtein = "\(Int(mergedProtein))g"
                todayCarbs = "\(Int(mergedCarbs))g"
                todayFat = "\(Int(mergedFat))g"
                todaySugar = mergedSugar
                todayCaloriesValue = mergedCals
                todayProteinValue = mergedProtein
                todayCarbsValue = mergedCarbs
                todayFatValue = mergedFat
                todaySugarValue = mergedSugar
                
                // Update daily challenge progress
                DailyChallengeManager.shared.updateProgress(for: .calories, value: calories)
                DailyChallengeManager.shared.updateProgress(for: .protein, value: protein)
            }
            syncWatchMetrics(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                sugar: sugar,
                water: waterIntake
            )
            print("✅ Synced with backend: \(Int(calories)) kcal")
        } catch {
            print("⚠️ Backend sync failed, using local cache: \(error.localizedDescription)")
            // Keep local cache values - don't clear them
            // Only log out on actual 401 (unauthorized) errors
            if let nsError = error as NSError?,
               nsError.code == 401 {
                print("❌ Unauthorized (401) - token expired or invalid. Logging out.")
                await MainActor.run {
                    auth.logout()
                }
            }
        }

        do {
            struct Fasting: Codable {
                let status: String
                let remainingHours: Double?
            }

            let fasting: Fasting =
                try await NetworkManager.shared.request(
                    "fasting/current",
                    method: "GET",
                    body: nil
                )

            if fasting.status == "fasting",
               let remaining = fasting.remainingHours,
               remaining.isFinite && !remaining.isNaN {

                let h = Int(remaining)
                let minutes = (remaining - Double(h)) * 60
                let m = minutes.isFinite && !minutes.isNaN ? Int(minutes) : 0
                fastingStatus = "\(h)h \(m)m"
            } else {
                fastingStatus = "Not fasting"
            }
        } catch {
            fastingStatus = "Not fasting"
        }
    }
    
    // Load liquid intake goal from backend
    private func loadLiquidIntakeGoal() async {
        guard auth.isLoggedIn else {
            return
        }
        
        guard let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty else {
            return
        }
        
        do {
            let response: [String: Any] = try await NetworkManager.shared.requestDictionary("auth/me", method: "GET", body: nil)
            if let metrics = response["metrics"] as? [String: Any],
               let liquid = metrics["liquidIntakeGoal"] as? Double {
                await MainActor.run {
                    liquidIntakeGoal = liquid
                }
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to load liquid intake goal: \(error.localizedDescription)")
            #endif
        }
    }
    
    // Load water intake from backend
    private func loadWaterIntake() async {
        guard auth.isLoggedIn else {
            return
        }
        
        guard let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty else {
            return
        }
        
        do {
            struct HealthSummary: Codable {
                let today: TodayData
            }
            
            struct TodayData: Codable {
                let water: Double?
            }
            
            // Force fresh fetch by adding timestamp to prevent caching
            let endpoint = "health/summary?t=\(Date().timeIntervalSince1970)"
            let summary: HealthSummary = try await NetworkManager.shared.request(
                endpoint,
                method: "GET",
                body: nil
            )
            
            await MainActor.run {
                waterIntake = summary.today.water ?? 0
                
                // Update daily challenge progress for water
                DailyChallengeManager.shared.updateProgress(for: .water, value: summary.today.water ?? 0)
            }
            syncWatchMetrics(
                calories: todayCaloriesValue,
                protein: todayProteinValue,
                carbs: todayCarbsValue,
                fat: todayFatValue,
                sugar: todaySugarValue,
                water: summary.today.water ?? 0
            )
        } catch {
            print("⚠️ Failed to load water intake: \(error.localizedDescription)")
        }
    }

    private func syncWatchMetrics(
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        sugar: Double,
        water: Double
    ) {
        let payload = WatchNutritionPayload(
            timestamp: Date(),
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: 0,
            sugar: sugar,
            water: water
        )
        WatchSyncManager.shared.sendNutritionUpdate(payload)
    }

    private var instantQuickLogButtons: some View {
        VStack(spacing: 12) {
            Button {
                HapticManager.shared.lightTap()
                showingScanner = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Design.Colors.primary)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
            }

            Button {
                HapticManager.shared.lightTap()
                showingLiquidLog = true
            } label: {
                Image(systemName: "drop.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(Design.Colors.water)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 4)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
    
    // Load health data from backend (steps, calories)
    private func loadHealthData() async {
        guard auth.isLoggedIn else {
            return
        }
        
        guard let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty else {
            return
        }
        
        do {
            struct HealthSummary: Codable {
                let today: TodayData
            }
            
            struct TodayData: Codable {
                let steps: Int?
                let activeCalories: Double?
            }
            
            // Force fresh fetch by adding timestamp to prevent caching
            let endpoint = "health/summary?t=\(Date().timeIntervalSince1970)"
            let summary: HealthSummary = try await NetworkManager.shared.request(
                endpoint,
                method: "GET",
                body: nil
            )
            
            await MainActor.run {
                // Update HealthKit service with backend data
                if let steps = summary.today.steps {
                    healthKit.todaySteps = steps
                    // Update daily challenge progress for steps
                    DailyChallengeManager.shared.updateProgress(for: .steps, value: Double(steps))
                }
                if let calories = summary.today.activeCalories {
                    healthKit.todayActiveCalories = calories
                }
            }
        } catch {
            print("⚠️ Failed to load health data: \(error.localizedDescription)")
        }
    }

    private func syncHealthData() async {
        // Use HealthKitService for syncing
        healthKit.checkAuthorizationStatus()
        
        if !healthKit.isAuthorized {
            do {
                print("🔵 Requesting HealthKit authorization...")
                try await healthKit.requestAuthorization()
            } catch {
                print("⚠️ HealthKit authorization failed: \(error.localizedDescription)")
            }
        }
        
        // Always try to read — Apple doesn't reveal read authorization status,
        // so isAuthorized may be false even when reads are granted.
        await healthKit.readTodayData()
        try? await healthKit.syncToBackend()
        print("✅ HealthKit data synced")
    }

    private func addWater() {
        Task {
            struct WaterReq: Codable { let amount: Double }
            let body = try? JSONEncoder().encode(WaterReq(amount: 0.25))

            do {
                let _: EmptyResponse = try await NetworkManager.shared.request(
                    "health/water",
                    method: "POST",
                    body: body
                )
                
                // Reload water intake after adding
                await loadWaterIntake()
            } catch {
                print("⚠️ Failed to add water: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Load Inline AI Recommendations
    private func loadInlineRecommendations() async {
        await MainActor.run { aiRecommendationLoading = true }
        
        // 1. Load built-in fallback data immediately
        let goal = auth.goal.isEmpty ? "maintain" : auth.goal
        let activityLevel = "moderate"
        let dietaryPreferences = auth.dietPrefs
        
        let fallbackMeals = FallbackDataService.shared.getRandomMeals(goal: goal, count: 4, useTimestamp: false, dietaryPreferences: dietaryPreferences)
        let fallbackWorkouts = FallbackDataService.shared.getRandomWorkouts(activityLevel: activityLevel, count: 4, useTimestamp: false)
        
        let fallbackRecommendation = RecommendationResponse(
            mealPlan: fallbackMeals,
            workoutPlan: fallbackWorkouts,
            hydrationGoal: HydrationGoal(targetLiters: 2.5),
            insights: [
                "✨ Daily rotating recipes and workouts",
                "🍽️ Complete ingredients and cooking instructions",
                "💪 Detailed workout instructions with sets & reps"
            ]
        )
        
        await MainActor.run {
            aiRecommendation = fallbackRecommendation
            isUsingFallback = true
            aiRecommendationLoading = false
        }
        
        // 2. Try to load AI recommendations from backend
        guard auth.isLoggedIn,
              let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty else {
            return
        }
        
        do {
            let response: RecommendationResponse = try await NetworkManager.shared.request(
                "recommendations/daily",
                method: "GET",
                body: nil
            )
            
            let hasMeals = !response.mealPlan.breakfast.isEmpty ||
                          !response.mealPlan.lunch.isEmpty ||
                          !response.mealPlan.dinner.isEmpty ||
                          !response.mealPlan.snacks.isEmpty
            let hasWorkouts = !response.workoutPlan.exercises.isEmpty
            
            if hasMeals || hasWorkouts {
                await MainActor.run {
                    aiRecommendation = response
                    isUsingFallback = false
                    print("✅ AI recommendations loaded for home dashboard")
                }
            }
        } catch {
            #if DEBUG
            print("⚠️ AI recommendations unavailable for home, using built-in: \(error.localizedDescription)")
            #endif
            // Keep fallback data - no need to do anything
        }
    }
}
