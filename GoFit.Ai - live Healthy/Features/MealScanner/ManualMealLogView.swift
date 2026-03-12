import SwiftUI

struct ManualMealLogView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var aiLookup = AINutritionLookup.shared
    
    @State private var mealType: String = "breakfast"
    @State private var items: [EditableParsedItem] = [EditableParsedItem(name: "", qtyText: "", calories: 0, protein: 0, carbs: 0, fat: 0, sugar: 0)]
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var showCelebration = false
    @State private var aiFilledIndex: Int? = nil
    
    let mealTypes = ["breakfast", "lunch", "dinner", "snack"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Design.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Design.Spacing.lg) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "pencil.and.list.clipboard")
                                .font(.system(size: 40))
                                .foregroundColor(Design.Colors.primary)
                            
                            Text("Log Your Meal")
                                .font(Design.Typography.title2)
                                .fontWeight(.bold)
                            
                            Text("Type food name & portion — AI fills the rest ✨")
                                .font(Design.Typography.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Design.Spacing.md)
                        
                        // Meal Type Selector
                        mealTypeSelector
                        
                        // Food Items
                        ForEach(Array(items.indices), id: \.self) { index in
                            foodItemCard(index: index)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                        
                        // Add Item Button
                        Button {
                            HapticManager.shared.mediumTap()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                items.append(EditableParsedItem(name: "", qtyText: "", calories: 0, protein: 0, carbs: 0, fat: 0, sugar: 0))
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Add Another Item")
                                    .font(Design.Typography.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(Design.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .padding(Design.Spacing.md)
                            .background(Design.Colors.primary.opacity(0.08))
                            .cornerRadius(16)
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
                        }
                        
                        // Totals Summary
                        if items.contains(where: { $0.calories > 0 }) {
                            totalsSummaryCard
                        }
                        
                        // Save Button
                        Button {
                            HapticManager.shared.mediumTap()
                            Task { await saveMeal() }
                        } label: {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                    Text("Save Meal")
                                        .font(Design.Typography.headline)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(Design.Spacing.md)
                            .background(
                                LinearGradient(
                                    colors: isSaving ? [Color.gray] : [Design.Colors.primary, Design.Colors.primary.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: Design.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(isSaving)
                        .padding(.bottom, Design.Spacing.xl)
                    }
                    .padding(.horizontal, Design.Spacing.md)
                }
                
                // Celebration overlay
                if showCelebration {
                    MealLogCelebration(isShowing: $showCelebration)
                        .ignoresSafeArea()
                }
            }
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.shared.lightTap()
                        dismiss()
                    }
                }
            }
            .alert("Meal Saved! 🎉", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your meal has been logged successfully.\n+\(RewardEngine.XPValues.mealLogged) XP earned!")
            }
        }
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Meal Type Selector
    private var mealTypeSelector: some View {
        HStack(spacing: Design.Spacing.sm) {
            ForEach(mealTypes, id: \.self) { type in
                Button {
                    HapticManager.shared.lightTap()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mealType = type
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mealTypeIcon(type))
                            .font(.title3)
                        Text(type.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Design.Spacing.sm)
                    .background(mealType == type ? Design.Colors.primary : Design.Colors.cardBackground)
                    .foregroundColor(mealType == type ? .white : .primary)
                    .cornerRadius(12)
                    .shadow(color: mealType == type ? Design.Colors.primary.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                }
            }
        }
    }
    
    private func mealTypeIcon(_ type: String) -> String {
        switch type {
        case "breakfast": return "sunrise.fill"
        case "lunch": return "sun.max.fill"
        case "dinner": return "moon.fill"
        case "snack": return "leaf.fill"
        default: return "fork.knife"
        }
    }
    
    // MARK: - Food Item Card
    private func foodItemCard(index: Int) -> some View {
        VStack(spacing: Design.Spacing.md) {
            // Food Name + AI Lookup
            HStack(spacing: Design.Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Food Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g., Chicken Biryani, Apple", text: $items[index].name)
                        .font(Design.Typography.body)
                        .dismissKeyboardOnSwipe()
                }
                .frame(maxWidth: .infinity)
                
                // AI Lookup Button
                Button {
                    HapticManager.shared.mediumTap()
                    Task { await aiAutoFill(index: index) }
                } label: {
                    VStack(spacing: 2) {
                        if aiLookup.isLoading && aiFilledIndex == index {
                            ProgressView()
                                .scaleEffect(0.8)
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20, weight: .semibold))
                        }
                        Text("AI Fill")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: .purple.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .disabled(items[index].name.isEmpty || (aiLookup.isLoading && aiFilledIndex == index))
            }
            
            // Portion
            VStack(alignment: .leading, spacing: 4) {
                Text("Portion Size")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g., 1 plate, 200g, 2 cups", text: $items[index].qtyText)
                    .font(Design.Typography.body)
                    .dismissKeyboardOnSwipe()
            }
            
            // Nutrition Grid (circular mini rings)
            nutritionCirclesGrid(index: index)
            
            // Delete button for non-first items
            if items.count > 1 {
                Button(role: .destructive) {
                    HapticManager.shared.lightTap()
                    let _ = withAnimation(.easeInOut(duration: 0.2)) {
                        items.remove(at: index)
                    }
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove Item")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Nutrition Circles Grid
    private func nutritionCirclesGrid(index: Int) -> some View {
        VStack(spacing: Design.Spacing.sm) {
            // Calories (prominent)
            HStack {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(items[index].calories / 500.0, 1.0))
                        .stroke(Design.Colors.calories, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5), value: items[index].calories)
                    
                    VStack(spacing: 0) {
                        Text("\(Int(items[index].calories))")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(Design.Colors.calories)
                        Text("kcal")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 64, height: 64)
                
                Spacer()
                
                // Editable calories field
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calories")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("0", value: $items[index].calories, format: .number)
                        .keyboardType(.decimalPad)
                        .font(Design.Typography.body)
                        .frame(width: 80)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Macro rings row
            HStack(spacing: Design.Spacing.md) {
                miniNutritionRing(
                    value: items[index].protein,
                    maxValue: 50,
                    label: "Protein",
                    unit: "g",
                    color: Design.Colors.protein,
                    binding: $items[index].protein
                )
                
                miniNutritionRing(
                    value: items[index].carbs,
                    maxValue: 80,
                    label: "Carbs",
                    unit: "g",
                    color: Design.Colors.carbs,
                    binding: $items[index].carbs
                )
                
                miniNutritionRing(
                    value: items[index].fat,
                    maxValue: 40,
                    label: "Fat",
                    unit: "g",
                    color: Design.Colors.fat,
                    binding: $items[index].fat
                )
                
                miniNutritionRing(
                    value: items[index].sugar,
                    maxValue: 30,
                    label: "Sugar",
                    unit: "g",
                    color: Design.Colors.sugar,
                    binding: $items[index].sugar
                )
            }
        }
    }
    
    private func miniNutritionRing(value: Double, maxValue: Double, label: String, unit: String, color: Color, binding: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: maxValue > 0 ? min(value / maxValue, 1.0) : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: value)
                
                Text("\(Int(value))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            .frame(width: 44, height: 44)
            
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            
            TextField("0", value: binding, format: .number)
                .keyboardType(.decimalPad)
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .frame(width: 44)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(6)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Totals Summary
    private var totalsSummaryCard: some View {
        let totalCals = items.reduce(0) { $0 + $1.calories }
        let totalProtein = items.reduce(0) { $0 + $1.protein }
        let totalCarbs = items.reduce(0) { $0 + $1.carbs }
        let totalFat = items.reduce(0) { $0 + $1.fat }
        
        return VStack(spacing: Design.Spacing.sm) {
            Text("Meal Totals")
                .font(Design.Typography.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: Design.Spacing.md) {
                VStack(spacing: 2) {
                    Text("\(Int(totalCals))")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(Design.Colors.calories)
                    Text("kcal")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: Design.Spacing.md) {
                    VStack(spacing: 2) {
                        Text("\(Int(totalProtein))g")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(Design.Colors.protein)
                        Text("Protein")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    VStack(spacing: 2) {
                        Text("\(Int(totalCarbs))g")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(Design.Colors.carbs)
                        Text("Carbs")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    VStack(spacing: 2) {
                        Text("\(Int(totalFat))g")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(Design.Colors.fat)
                        Text("Fat")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(Design.Spacing.lg)
        .background(
            LinearGradient(
                colors: [Design.Colors.primary.opacity(0.05), Design.Colors.primary.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(16)
    }
    
    // MARK: - AI Auto Fill
    private func aiAutoFill(index: Int) async {
        guard !items[index].name.isEmpty else { return }
        
        await MainActor.run {
            aiFilledIndex = index
        }
        
        if let result = await aiLookup.lookup(foodName: items[index].name, portion: items[index].qtyText) {
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    items[index].calories = result.calories
                    items[index].protein = result.protein
                    items[index].carbs = result.carbs
                    items[index].fat = result.fat
                    items[index].sugar = result.sugar
                }
                HapticManager.shared.success()
                aiFilledIndex = nil
            }
        } else {
            await MainActor.run {
                HapticManager.shared.error()
                errorMessage = "Could not find nutrition data for \"\(items[index].name)\". Try a more specific name."
                aiFilledIndex = nil
                
                // Auto-clear error
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { errorMessage = nil }
                }
            }
        }
    }
    
    // MARK: - Save Meal
    private func saveMeal() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        
        // Filter out empty items
        let validItems = items.filter { !$0.name.isEmpty }
        guard !validItems.isEmpty else {
            errorMessage = "Please add at least one food item"
            return
        }
        
        // 1️⃣ CALCULATE TOTALS
        let totalCals = validItems.reduce(0) { $0 + $1.calories }
        let totalProtein = validItems.reduce(0) { $0 + $1.protein }
        let totalCarbs = validItems.reduce(0) { $0 + $1.carbs }
        let totalFat = validItems.reduce(0) { $0 + $1.fat }
        let totalSugar = validItems.reduce(0) { $0 + $1.sugar }
        
        // 2️⃣ CREATE MEAL ENTRY FOR LOCAL CACHE
        let mealEntry = MealEntry(
            name: validItems.map { $0.name }.joined(separator: ", "),
            calories: totalCals,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            date: Date(),
            mealType: "manual"
        )
        
        // 3️⃣ SAVE TO LOCAL CACHE IMMEDIATELY (Offline-first)
        let cachedItems = validItems.map { item in
            CachedMeal.CachedMealItem(
                name: item.name,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                sugar: item.sugar,
                portionSize: item.qtyText.isEmpty ? nil : item.qtyText
            )
        }
        
        let cachedMeal = CachedMeal(
            id: UUID().uuidString,
            timestamp: Date(),
            items: cachedItems,
            totalCalories: totalCals,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat,
            totalSugar: totalSugar,
            mealType: "manual",
            synced: false
        )
        
        LocalMealCache.shared.addMeal(cachedMeal)
        
        await MainActor.run {
            UserDataCache.shared.addMealEntry(mealEntry)
            AppLogger.shared.meal("💾 Saved manual meal to cache: \(mealEntry.name)")
        }
        
        // 4️⃣ ALSO ADD TO DAILY LOG FOR HISTORICAL TRACKING
        let mealItems = validItems.map { item in
            MealItem(
                name: item.name,
                calories: item.calories,
                protein: item.protein,
                carbs: item.carbs,
                fat: item.fat,
                sugar: item.sugar,
                portionSize: nil,
                quantity: item.qtyText.isEmpty ? nil : item.qtyText
            )
        }
        
        let loggedMeal = LoggedMeal(
            timestamp: Date(),
            mealType: .snack,
            items: mealItems,
            totalCalories: totalCals,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat,
            totalSugar: totalSugar
        )
        
        await MainActor.run {
            LocalDailyLogStore.shared.addMeal(loggedMeal)
        }
        
        // 5️⃣ REWARD & CELEBRATE
        await MainActor.run {
            RewardEngine.shared.rewardMealLog()
            NotificationCenter.default.post(name: NSNotification.Name("MealSaved"), object: nil)
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                showCelebration = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showSuccess = true
            }
        }
        
        // 6️⃣ SYNC TO BACKEND IN BACKGROUND (Non-blocking)
        let userId = authVM.userId
        Task.detached(priority: .utility) {
            do {
                let dto = validItems.map { ParsedItemDTO(name: $0.name, qtyText: $0.qtyText, calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat, sugar: $0.sugar) }
                _ = try await NetworkManager.shared.saveParsedMeal(userId: userId, items: dto)
                
                await MainActor.run {
                    AppLogger.shared.meal("✅ Synced manual meal to backend: \(mealEntry.name)")
                }
            } catch {
                await MainActor.run {
                    AppLogger.shared.logError(error, context: "Failed to sync manual meal to backend")
                    print("⚠️ Manual meal remains in local cache, will retry on next sync")
                }
            }
        }
    }
}

