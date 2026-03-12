import SwiftUI

struct LiquidLogView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var beverageType: String = "water"
    @State private var beverageName: String = ""
    @State private var amount: Double = 0.25 // Default 250ml
    @State private var calories: Double = 0
    @State private var sugar: Double = 0
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var todayEntries: [LiquidEntry] = []
    @State private var liquidGoal: Double = AppConstants.defaultWaterGoal
    
    let beverageTypes = [
        ("water", "Water", "drop.fill"),
        ("soda", "Soda", "bubbles.and.sparkles"),
        ("soft_drink", "Soft Drink", "cup.and.saucer.fill"),
        ("juice", "Juice", "leaf.fill"),
        ("coffee", "Coffee", "cup.fill"),
        ("tea", "Tea", "cup.and.saucer"),
        ("beer", "Beer", "mug.fill"),
        ("wine", "Wine", "wineglass.fill"),
        ("liquor", "Liquor", "wineglass"),
        ("other", "Other", "drop")
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Design.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Design.Spacing.lg) {
                        // Human body liquid visualization
                        HumanBodyLiquidView(
                            entries: todayEntries,
                            goal: liquidGoal
                        )
                        .frame(height: 320)
                        .padding(.horizontal, Design.Spacing.md)
                        
                        // Beverage Type Grid
                        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
                            Text("Choose Beverage")
                                .font(Design.Typography.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal, Design.Spacing.md)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 12) {
                                ForEach(beverageTypes, id: \.0) { type, name, icon in
                                    Button {
                                        HapticManager.shared.lightTap()
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            beverageType = type
                                        }
                                    } label: {
                                        VStack(spacing: 6) {
                                            ZStack {
                                                Circle()
                                                    .fill(beverageType == type ? beverageColor(type) : Color.gray.opacity(0.1))
                                                    .frame(width: 48, height: 48)
                                                
                                                Image(systemName: icon)
                                                    .font(.system(size: 18))
                                                    .foregroundColor(beverageType == type ? .white : .secondary)
                                            }
                                            
                                            Text(name)
                                                .font(.system(size: 9, weight: .medium))
                                                .foregroundColor(beverageType == type ? beverageColor(type) : .secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, Design.Spacing.md)
                        }
                        
                        // Beverage Name (for non-water)
                        if beverageType != "water" {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Beverage Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("e.g., Coca Cola, Green Tea", text: $beverageName)
                                    .font(Design.Typography.body)
                                    .padding(Design.Spacing.sm)
                                    .background(Design.Colors.cardBackground)
                                    .cornerRadius(12)
                                    .dismissKeyboardOnSwipe()
                            }
                            .padding(.horizontal, Design.Spacing.md)
                        }
                        
                        // Amount Section
                        VStack(spacing: Design.Spacing.md) {
                            // Amount Display
                            HStack {
                                Text("Amount")
                                    .font(Design.Typography.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(Int(amount * 1000))ml")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(beverageColor(beverageType))
                            }
                            
                            // Slider
                            Slider(value: $amount, in: 0.1...2.0, step: 0.05)
                                .tint(beverageColor(beverageType))
                                .onChange(of: amount) {
                                    HapticManager.shared.lightTap()
                                }
                            
                            // Quick amount buttons
                            HStack(spacing: Design.Spacing.sm) {
                                ForEach([0.25, 0.33, 0.5, 0.75, 1.0], id: \.self) { value in
                                    Button {
                                        HapticManager.shared.lightTap()
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            amount = value
                                        }
                                    } label: {
                                        Text("\(Int(value * 1000))ml")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(amount == value ? beverageColor(beverageType) : Color.gray.opacity(0.1))
                                            .foregroundColor(amount == value ? .white : .primary)
                                            .cornerRadius(10)
                                    }
                                }
                            }
                        }
                        .padding(Design.Spacing.lg)
                        .background(Design.Colors.cardBackground)
                        .cornerRadius(16)
                        .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, Design.Spacing.md)
                        
                        // Nutrition card (non-water)
                        if beverageType != "water" {
                            HStack(spacing: Design.Spacing.lg) {
                                VStack(spacing: 4) {
                                    Text("\(Int(calculateCalories()))")
                                        .font(.system(.title2, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundColor(Design.Colors.calories)
                                    Text("Calories")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                
                                Divider()
                                    .frame(height: 40)
                                
                                VStack(spacing: 4) {
                                    Text("\(String(format: "%.1f", calculateSugar()))g")
                                        .font(.system(.title2, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundColor(Design.Colors.sugar)
                                    Text("Sugar")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .padding(Design.Spacing.lg)
                            .background(Design.Colors.cardBackground)
                            .cornerRadius(16)
                            .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
                            .padding(.horizontal, Design.Spacing.md)
                        }
                        
                        // Error
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(Design.Typography.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(Design.Spacing.md)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, Design.Spacing.md)
                        }
                        
                        // Save Button
                        Button {
                            HapticManager.shared.mediumTap()
                            Task { await saveLiquid() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "drop.fill")
                                        .font(.title3)
                                    Text("Log \(beverageType == "water" ? "Water" : "Beverage")")
                                        .font(Design.Typography.headline)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(Design.Spacing.md)
                            .background(
                                LinearGradient(
                                    colors: [beverageColor(beverageType), beverageColor(beverageType).opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: beverageColor(beverageType).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isSaving || amount <= 0)
                        .padding(.horizontal, Design.Spacing.md)
                        .padding(.bottom, Design.Spacing.xl)
                    }
                }
            }
            .navigationTitle("Log Liquid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.lightTap()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadTodayEntries()
            }
            .alert("Liquid Logged! 💧", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("+\(RewardEngine.XPValues.liquidLogged) XP earned!")
            }
        }
    }
    
    // MARK: - Beverage Color
    private func beverageColor(_ type: String) -> Color {
        switch type {
        case "water": return .cyan
        case "coffee": return Color(red: 0.45, green: 0.25, blue: 0.1)
        case "tea": return .green
        case "juice": return .orange
        case "soda", "soft_drink": return Color(red: 0.6, green: 0.15, blue: 0.1)
        case "beer": return Color(red: 0.85, green: 0.65, blue: 0.15)
        case "wine": return Color(red: 0.5, green: 0.05, blue: 0.15)
        case "liquor": return Color(red: 0.6, green: 0.4, blue: 0.15)
        default: return .gray
        }
    }
    
    // MARK: - Load Today's Entries
    private func loadTodayEntries() {
        if let log = LocalDailyLogStore.shared.getToday() {
            todayEntries = log.liquidEntries
        }
    }
    
    // MARK: - Save
    private func saveLiquid() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        do {
            struct WaterLogRequest: Codable {
                let amount: Double
                let beverageType: String
                let beverageName: String
                let calories: Double
                let sugar: Double
            }
            
            struct WaterLogResponse: Codable {
                let _id: String?
                let amount: Double
                let beverageType: String
            }
            
            let requestBody = WaterLogRequest(
                amount: amount,
                beverageType: beverageType,
                beverageName: beverageName,
                calories: calculateCalories(),
                sugar: calculateSugar()
            )
            
            let bodyData = try JSONEncoder().encode(requestBody)
            
            let _: WaterLogResponse = try await NetworkManager.shared.request(
                "health/water",
                method: "POST",
                body: bodyData
            )
            
            // Also save to daily log store for historical tracking
            let beverageTypeEnum = LiquidEntry.BeverageType(rawValue: beverageType) ?? .water
            let liquidEntry = LiquidEntry(
                timestamp: Date(),
                amount: amount,
                beverageType: beverageTypeEnum,
                beverageName: beverageName.isEmpty ? nil : beverageName,
                calories: calculateCalories(),
                sugar: calculateSugar()
            )
            LocalDailyLogStore.shared.addLiquidIntake(liquidEntry)
            
            // Update body visualization
            await MainActor.run {
                todayEntries.append(liquidEntry)
                
                // Reward
                RewardEngine.shared.rewardLiquidLog(beverageType: beverageType)
                
                showSuccess = true
            }
        } catch {
            print("❌ Failed to log liquid: \(error)")
            await MainActor.run {
                if let nsError = error as NSError? {
                    let errorMessageText = nsError.userInfo[NSLocalizedDescriptionKey] as? String ?? error.localizedDescription
                    errorMessage = "Failed to log liquid: \(errorMessageText)"
                } else {
                    errorMessage = "Failed to log liquid: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Calculate calories based on beverage type and amount
    private func calculateCalories() -> Double {
        if beverageType == "water" { return 0 }
        
        let caloriesPerLiter: [String: Double] = [
            "soda": 420,
            "soft_drink": 420,
            "juice": 450,
            "coffee": 2,
            "tea": 2,
            "beer": 430,
            "wine": 830,
            "liquor": 2310,
            "other": 0
        ]
        
        return Double(Int((caloriesPerLiter[beverageType] ?? 0) * amount))
    }
    
    // Calculate sugar based on beverage type and amount
    private func calculateSugar() -> Double {
        if beverageType == "water" { return 0 }
        
        let sugarPerLiter: [String: Double] = [
            "soda": 108,
            "soft_drink": 108,
            "juice": 100,
            "coffee": 0,
            "tea": 0,
            "beer": 0,
            "wine": 2,
            "liquor": 0,
            "other": 0
        ]
        
        return round((sugarPerLiter[beverageType] ?? 0) * amount * 10) / 10
    }
}

