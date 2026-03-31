

import SwiftUI
import Combine

struct TargetSettingsView: View {

        @ObservedObject private var bodyLogManager = BodyLogManager.shared
        @State private var cancellable: AnyCancellable?
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss

    @State private var isLoadingTargets = false
    @State private var weightKg: Double = 70
    @State private var heightCm: Double = 170
    @State private var targetWeightKg: Double? = 70
    @State private var targetTimeWeeks: Int = 12
    @State private var targetCalories: Double? = 2000
    @State private var targetProtein: Double? = 120
    @State private var targetCarbs: Double? = 240
    @State private var targetFat: Double? = 70
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
        bodyContent
    }

    @ViewBuilder
    private var bodyContent: some View {
        NavigationStack {
            ZStack {
                Design.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    mainVStack
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
                // Observe latestWeight and auto-update
                cancellable = bodyLogManager.$latestWeight.sink { newWeight in
                    guard let newWeight, newWeight > 0, abs(newWeight - weightKg) > 0.01 else { return }
                    weightKg = newWeight
                    recalculateTargets()
                }
            }
            .onDisappear {
                cancellable?.cancel()
            }
            .alert("Error", isPresented: $showingError, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text(errorMessage ?? "An error occurred")
            })
            .alert("Success", isPresented: $showingSuccess, actions: {
                Button("OK") {
                    skipLoadOnAppear = false
                    dismiss()
                }
            }, message: {
                Text("Your targets have been updated successfully!")
            })
        }
    }

    @ViewBuilder
    private var mainVStack: some View {
        VStack(spacing: Design.Spacing.xl) {
            bodyMetricsCard
            goalsCard
            nutritionTargetsCard
            hydrationCard
            errorCard
            saveButton
        }
        .padding(.top, Design.Spacing.md)
    }

    @ViewBuilder
    private var hydrationCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: Design.Spacing.md) {
                Text("Hydration Goal")
                    .font(Design.Typography.headline)
                    .foregroundColor(.primary)

                HStack {
                    Text("Liquid Intake (L)")
                        .font(Design.Typography.body)
                        .foregroundColor(.secondary)
                    Spacer()
                    TextField("2.5", value: $liquidIntakeGoal, format: .number)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }

                Text("Set your daily water/liquid intake goal. Default is 2.5L.")
                    .font(Design.Typography.caption)
                    .foregroundColor(.secondary)
            }
            .padding(Design.Spacing.md)
        }
        .padding(.horizontal, Design.Spacing.md)
    }

    @ViewBuilder
    private var errorCard: some View {
        if let error = errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text(error)
                    .font(Design.Typography.body)
                    .foregroundColor(.red)
            }
            .padding(Design.Spacing.md)
            .background(Design.Colors.secondaryBackground)
            .cornerRadius(Design.Radius.medium)
            .padding(.horizontal, Design.Spacing.md)
        }
    }

    @ViewBuilder
    private var saveButton: some View {
        Button(action: saveTargets) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text(isLoading ? "Saving..." : "Save Changes")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isLoading ? AnyShapeStyle(Color.gray) : AnyShapeStyle(Design.Colors.primaryGradient))
            .cornerRadius(16)
            .shadow(color: Design.Colors.primary.opacity(0.2), radius: 10, x: 0, y: 6)
        }
        .disabled(isLoading)
        .padding(.horizontal, Design.Spacing.md)
        .padding(.bottom, Design.Spacing.xl)
    }

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
                        TextField("kg", value: $weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 90)
                            .textFieldStyle(.roundedBorder)
                        Text("kg").foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Height")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("cm", value: $heightCm, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 90)
                            .textFieldStyle(.roundedBorder)
                        Text("cm").foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Target Weight")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("kg", value: Binding(get: { targetWeightKg ?? 0 }, set: { targetWeightKg = $0 }), format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 90)
                            .textFieldStyle(.roundedBorder)
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
                        TextField("kcal", value: $targetCalories, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 90)
                            .textFieldStyle(.roundedBorder)
                        Text("kcal").foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Target Protein")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("g", value: $targetProtein, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 90)
                            .textFieldStyle(.roundedBorder)
                        Text("g").foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Target Carbs")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("g", value: $targetCarbs, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 90)
                            .textFieldStyle(.roundedBorder)
                        Text("g").foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Target Fat")
                            .font(Design.Typography.body)
                            .foregroundColor(.primary)
                        Spacer()
                        TextField("g", value: $targetFat, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(width: 90)
                            .textFieldStyle(.roundedBorder)
                        Text("g").foregroundColor(.secondary)
                    }
                }

                Button(action: recalculateTargets) {
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

    private func loadCurrentTargets() {
        weightKg = auth.weightKg
        heightCm = auth.heightCm
        goal = auth.goal

        Task {
            do {
                let response: [String: Any] = try await NetworkManager.shared.requestDictionary("auth/me", method: "GET", body: nil)
                await MainActor.run {
                    applyProfileResponse(response)
                    isLoadingTargets = false
                }
            } catch {
                print("⚠️ Failed to load targets: \(error.localizedDescription)")
                isLoadingTargets = false
            }
        }
    }

    private func numberAsDouble(_ value: Any?) -> Double? {
        switch value {
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private func numberAsInt(_ value: Any?) -> Int? {
        switch value {
        case let int as Int:
            return int
        case let double as Double:
            return Int(double)
        case let number as NSNumber:
            return number.intValue
        case let string as String:
            return Int(string)
        default:
            return nil
        }
    }

    private func applyProfileResponse(_ response: [String: Any]) {
        if let metrics = response["metrics"] as? [String: Any] {
            if let w = numberAsDouble(metrics["weightKg"]) { weightKg = w }
            if let h = numberAsDouble(metrics["heightCm"]) { heightCm = h }
            if let tw = numberAsDouble(metrics["targetWeightKg"]) { targetWeightKg = tw }
            if let tc = numberAsDouble(metrics["targetCalories"]) { targetCalories = tc }
            if let tp = numberAsDouble(metrics["targetProtein"]) { targetProtein = tp }
            if let tcarbs = numberAsDouble(metrics["targetCarbs"]) { targetCarbs = tcarbs }
            if let tf = numberAsDouble(metrics["targetFat"]) { targetFat = tf }
            if let liquid = numberAsDouble(metrics["liquidIntakeGoal"]) { liquidIntakeGoal = liquid }
            if let weeks = numberAsInt(metrics["targetTimeWeeks"]) { targetTimeWeeks = weeks }
        }

        if let savedGoal = response["goals"] as? String, !savedGoal.isEmpty {
            goal = savedGoal
        }
        if let savedActivity = response["activityLevel"] as? String, !savedActivity.isEmpty {
            activityLevel = savedActivity
        }

        auth.weightKg = weightKg
        auth.heightCm = heightCm
        auth.goal = goal
        auth.saveLocalState()

        LocalUserStore.shared.updateBasicInfo(weightKg: weightKg, heightCm: heightCm, targetWeightKg: targetWeightKg, targetTimeWeeks: targetTimeWeeks)
        LocalUserStore.shared.updateGoals(goal: goal, activityLevel: activityLevel)
        LocalUserStore.shared.updateNutritionTargets(
            targetCalories: targetCalories,
            targetProtein: targetProtein,
            targetCarbs: targetCarbs,
            targetFat: targetFat,
            liquidIntakeGoal: liquidIntakeGoal
        )
        WaterIntakeManager.shared.waterGoal = liquidIntakeGoal
    }

    private func recalculateTargets() {
        guard weightKg > 0, heightCm > 0, let targetWeight = targetWeightKg, targetWeight > 0 else {
            errorMessage = "Please enter valid current and target weight values."
            showingError = true
            return
        }

        let age = 30.0
        let bmrMale = 10 * weightKg + 6.25 * heightCm - 5 * age + 5
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

        targetCalories = max(1100, tdee + changeCalories)
        targetProtein = round((targetCalories ?? 0) * 0.25 / 4)
        targetCarbs = round((targetCalories ?? 0) * 0.45 / 4)
        targetFat = round((targetCalories ?? 0) * 0.30 / 9)

        LocalUserStore.shared.updateNutritionTargets(targetCalories: targetCalories, targetProtein: targetProtein, targetCarbs: targetCarbs, targetFat: targetFat)
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
                    "goals": goal,
                    "activityLevel": activityLevel
                ]
                let cleanBody = body.compactMapValues { $0 }
                let bodyData = try JSONSerialization.data(withJSONObject: cleanBody, options: [])
                let response: [String: Any] = try await NetworkManager.shared.requestDictionary("auth/targets", method: "PUT", body: bodyData)

                await MainActor.run {
                    applyProfileResponse(response)
                    LocalUserStore.shared.updateGoals(goal: goal, activityLevel: activityLevel)
                    WaterIntakeManager.shared.waterGoal = liquidIntakeGoal
                    GoFitSmartNotifications.shared.scheduleSmartNotifications()
                    isLoading = false
                    showingSuccess = true
                    skipLoadOnAppear = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    if let nsError = error as NSError?, let message = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                        errorMessage = message
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showingError = true
                }
            }
        }
    }
}
