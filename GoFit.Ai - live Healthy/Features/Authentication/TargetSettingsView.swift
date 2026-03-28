import SwiftUI

struct TargetSettingsView: View {
    // MARK: - Subviews
    private var bodyMetricsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: Design.Spacing.md) {
                Text("Body Metrics")
                    .font(Design.Typography.headline)
                    .foregroundColor(.primary)
                VStack(spacing: Design.Spacing.md) {
                    HStack {
                        Text("Current Weight")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("kg", value: $weightKg, format: .number, onEditingChanged: { editing in
                            if !editing { saveTargets() }
                        })
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .accentColor(Design.Colors.primary)
                            .cornerRadius(8)
                            .frame(width: 100)
                        Text("kg").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Height")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("cm", value: $heightCm, format: .number)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .accentColor(Design.Colors.primary)
                            .cornerRadius(8)
                            .frame(width: 100)
                        Text("cm").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Target Weight")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("kg", value: $targetWeightKg, format: .number, onEditingChanged: { editing in
                            if !editing { saveTargets() }
                        })
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .accentColor(Design.Colors.primary)
                            .cornerRadius(8)
                            .frame(width: 100)
                        Text("kg").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Target Timeframe")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        Stepper(value: $targetTimeWeeks, in: 4...52, step: 1) {
                            Text("\(targetTimeWeeks) weeks")
                                .font(Design.Typography.body)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 200)
                    }
                    HStack {
                        Spacer()
                        Button(action: recalculateTargets) {
                            Text("Recalculate Calories")
                                .font(Design.Typography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Design.Colors.primary)
                                .cornerRadius(10)
                        }
                        Spacer()
                    }
                }
            }
            .padding(Design.Spacing.md)
        }
        .padding(.horizontal, Design.Spacing.md)
    }

    private var goalsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: Design.Spacing.md) {
                Text("Fitness Goal")
                    .font(Design.Typography.headline)
                    .foregroundColor(.primary)
                Picker("Goal", selection: $goal) {
                    ForEach(goals, id: \.self) { goalOption in
                        Text(goalOption.capitalized).tag(goalOption)
                    }
                }
                .pickerStyle(.segmented)
                Text("Activity Level")
                    .font(Design.Typography.body)
                    .padding(.top, Design.Spacing.sm)
                Picker("Activity Level", selection: $activityLevel) {
                    ForEach(activityLevels, id: \.self) { level in
                        Text(level.replacingOccurrences(of: "_", with: " ").capitalized).tag(level)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(Design.Spacing.md)
        }
        .padding(.horizontal, Design.Spacing.md)
    }

    private var nutritionTargetsCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: Design.Spacing.md) {
                Text("Nutrition Targets")
                    .font(Design.Typography.headline)
                    .foregroundColor(.primary)
                VStack(spacing: Design.Spacing.md) {
                    HStack {
                        Text("Target Calories")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("kcal", value: $targetCalories, format: .number, onEditingChanged: { editing in
                            if !editing { saveTargets() }
                        })
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .accentColor(Design.Colors.primary)
                            .cornerRadius(8)
                            .frame(width: 100)
                        Text("kcal").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Target Protein")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("g", value: $targetProtein, format: .number)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .accentColor(Design.Colors.primary)
                            .cornerRadius(8)
                            .frame(width: 100)
                        Text("g").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Target Carbs")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("g", value: $targetCarbs, format: .number)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .accentColor(Design.Colors.primary)
                            .cornerRadius(8)
                            .frame(width: 100)
                        Text("g").foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Target Fat")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("g", value: $targetFat, format: .number)
                            .keyboardType(.decimalPad)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .foregroundColor(.primary)
                            .accentColor(Design.Colors.primary)
                            .cornerRadius(8)
                            .frame(width: 100)
                        Text("g").foregroundColor(.secondary)
                    }
                }
                Button(action: {
                    recalculateTargets()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Recalculate Targets")
                    }
                    .font(Design.Typography.body)
                    .foregroundColor(Design.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.sm)
                    .background(Design.Colors.primary.opacity(0.1))
                    .cornerRadius(Design.Radius.medium)
                }
                .padding(.top, Design.Spacing.sm)
            }
            .padding(Design.Spacing.md)
        }
        .padding(.horizontal, Design.Spacing.md)
    }

        @State private var isLoadingTargets = false
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var weightKg: Double = 70
    @State private var heightCm: Double = 170
    @State private var targetWeightKg: Double?
    @State private var targetTimeWeeks: Int = 12
    @State private var targetCalories: Double?
    @State private var targetProtein: Double?
    @State private var targetCarbs: Double?
    @State private var targetFat: Double?
    @State private var liquidIntakeGoal: Double = 2.5
    @State private var goal: String = "maintain"
    @State private var activityLevel: String = "moderate"
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var skipLoadOnAppear = false
    
    let goals = ["lose", "maintain", "gain"]
    let activityLevels = ["sedentary", "light", "moderate", "active", "very_active"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Design.Spacing.xl) {
                        // Weight and Height
                        ModernCard {
                            VStack(alignment: .leading, spacing: Design.Spacing.md) {
                                Text("Body Metrics")
                                    .font(Design.Typography.headline)
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: Design.Spacing.md) {
                                    HStack {
                                        Text("Current Weight")
                                            .font(Design.Typography.body)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        TextField("kg", value: $weightKg, format: .number, onEditingChanged: { editing in
                                            NavigationStack {
                                                ZStack {
                                                    Design.Colors.background
                                                        .ignoresSafeArea()
                                                    ScrollView {
                                                        VStack(spacing: Design.Spacing.xl) {
                                                            bodyMetricsCard
                                                            goalsCard
                                                            nutritionTargetsCard
                                        .cornerRadius(8)
                                        .frame(width: 100)
                                    Text("L")
                                        .foregroundColor(.secondary)
                                }
                                
                                Text("Set your daily water/liquid intake goal. The default is 2.5L per day.")
                                    .font(Design.Typography.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.top, Design.Spacing.xs)
                            }
                            .padding(Design.Spacing.md)
                        }
                        .padding(.horizontal, Design.Spacing.md)
                        
                        // Error message
                        if let error = errorMessage {
                            HStack(spacing: Design.Spacing.sm) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(Design.Typography.body)
                                    .foregroundColor(.red)
                            }
                            .padding(Design.Spacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Design.Colors.secondaryBackground)
                        .cornerRadius(Design.Radius.medium)
                        .padding(.horizontal, Design.Spacing.md)
                        }
                        
                        // Save button
                        Button(action: saveTargets) {
                            HStack(spacing: 12) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                    Text("Save Changes")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .background(
                                Group {
                                    if !isLoading {
                                        Design.Colors.primaryGradient
                                    } else {
                                        LinearGradient(
                                            colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    }
                                }
                            )
                            .cornerRadius(16)
                            .shadow(color: Design.Colors.primary.opacity(isLoading ? 0 : 0.4), radius: 12, x: 0, y: 6)
                        }
                        .disabled(isLoading)
                        .padding(.horizontal, Design.Spacing.md)
                        .padding(.bottom, Design.Spacing.xl)
                    }
                    .padding(.top, Design.Spacing.md)
                }
            }
            .navigationTitle("Goals & Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Design.Colors.primary)
                }
            }
            .onAppear {
                if !skipLoadOnAppear && !isLoadingTargets {
                    isLoadingTargets = true
                    loadCurrentTargets()
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {
                    skipLoadOnAppear = false
                    dismiss()
                }
            } message: {
                Text("Your targets have been updated successfully!")
            }
        }
    }
    
    private func loadCurrentTargets() {
        weightKg = auth.weightKg
        heightCm = auth.heightCm
        goal = auth.goal
        
        // Load from backend if available
        Task {
            do {
                let response: [String: Any] = try await NetworkManager.shared.requestDictionary("auth/me", method: "GET", body: nil)
                await MainActor.run {
                    if let metrics = response["metrics"] as? [String: Any] {
                        if let w = metrics["weightKg"] as? Double {
                            weightKg = w
                        }
                        if let h = metrics["heightCm"] as? Double {
                            if isLoadingTargets == false { isLoadingTargets = true }
                            heightCm = h
                        }
                        if let tw = metrics["targetWeightKg"] as? Double {
                            targetWeightKg = tw
                        }
                        if let tc = metrics["targetCalories"] as? Double {
                            targetCalories = tc
                        }
                        if let tp = metrics["targetProtein"] as? Double {
                            targetProtein = tp
                        }
                        if let tcarbs = metrics["targetCarbs"] as? Double {
                            targetCarbs = tcarbs
                        }
                    if let tf = metrics["targetFat"] as? Double {
                        targetFat = tf
                    }
                    if let liquid = metrics["liquidIntakeGoal"] as? Double {
                        liquidIntakeGoal = liquid
                    }
                    if let weeks = metrics["targetTimeWeeks"] as? Int {
                        targetTimeWeeks = weeks
                    }
                }
                if let activity = response["activityLevel"] as? String {
                    activityLevel = activity
                }
                }
            } catch {
                print("⚠️ Failed to load targets: \(error.localizedDescription)")
            }
        }
    }
    
    private func recalculateTargets() {
        guard weightKg > 0, heightCm > 0, let targetWeight = targetWeightKg, targetWeight > 0 else {
            errorMessage = "Please enter valid current and target weight values."
            showingError = true
            return
        }

                                    isLoadingTargets = false
        let age = 30.0
        let bmrMale = 10 * weightKg + 6.25 * heightCm - 5 * age + 5
                                    isLoadingTargets = false
        let bmrFemale = 10 * weightKg + 6.25 * heightCm - 5 * age - 161
        let bmr = (bmrMale + bmrFemale) / 2

        let activityMultiplier: Double
        switch activityLevel {
        case "sedentary": activityMultiplier = 1.2
        case "light": activityMultiplier = 1.375
        case "moderate": activityMultiplier = 1.55
        case "active": activityMultiplier = 1.725
        case "very_active": activityMultiplier = 1.9
        default: activityMultiplier = 1.55
        }

        let tdee = bmr * activityMultiplier

        let weeks = max(targetTimeWeeks, 4)
        let deltaKg = targetWeight - weightKg
        let dailyWeightChange = deltaKg / Double(weeks * 7)
        let changeCalories = dailyWeightChange * 7700

        let base = tdee
        let daily = base + changeCalories

        targetCalories = max(1100, daily)

        // optional macro split suggestions
        targetProtein = round((targetCalories ?? 0) * 0.25 / 4)
        targetCarbs = round((targetCalories ?? 0) * 0.45 / 4)
        targetFat = round((targetCalories ?? 0) * 0.30 / 9)

        // update local user store quickly
        LocalUserStore.shared.updateNutritionTargets(targetCalories: targetCalories, targetProtein: targetProtein, targetCarbs: targetCarbs, targetFat: targetFat)

        // send to backend as well
        saveTargets()
    }
    
    private func saveTargets() {
        errorMessage = nil
        isLoading = true
        Task {
            do {
                let body: [String: Any?] = [
                    "weightKg": weightKg,
                    "heightCm": heightCm,
                    "targetWeightKg": targetWeightKg,
                    "targetTimeWeeks": targetTimeWeeks,
                    "targetCalories": targetCalories,
                    "targetProtein": targetProtein,
                    "targetCarbs": targetCarbs,
                    "targetFat": targetFat,
                    "liquidIntakeGoal": liquidIntakeGoal,
                    "goals": goal, // always use plural to match backend
                    "activityLevel": activityLevel
                ]
                let cleanBody = body.compactMapValues { $0 }
                let bodyData = try JSONSerialization.data(withJSONObject: cleanBody, options: [])
                let _: [String: Any] = try await NetworkManager.shared.requestDictionary(
                    "auth/targets",
                    method: "PUT",
                    body: bodyData
                )
                await MainActor.run {
                    // Update local auth state
                    auth.weightKg = weightKg
                    auth.heightCm = heightCm
                    auth.goal = goal
                    auth.saveLocalState()

                    // Keep local cache in sync
                    LocalUserStore.shared.updateBasicInfo(weightKg: weightKg, heightCm: heightCm, targetWeightKg: targetWeightKg)
                    LocalUserStore.shared.updateNutritionTargets(targetCalories: targetCalories, targetProtein: targetProtein, targetCarbs: targetCarbs, targetFat: targetFat, liquidIntakeGoal: liquidIntakeGoal)

                    isLoading = false
                    showingSuccess = true
                    skipLoadOnAppear = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let nsError = error as NSError? {
                        if let message = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                            errorMessage = message
                        } else {
                            errorMessage = error.localizedDescription
                        }
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showingError = true
                }
            }
        }
    }
}

