import SwiftUI

// MARK: - Tab View
struct WatchTabView: View {
    var body: some View {
        TabView {
            WatchDashboardView()
            WatchWaterView()
            WatchQuickLogView()
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Dashboard
struct WatchDashboardView: View {
    @EnvironmentObject var conn: WatchConnectivityManager
    
    private let brandGreen = Color(red: 0.2, green: 0.85, blue: 0.4)
    private let brandBlue = Color(red: 0.3, green: 0.6, blue: 1.0)
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(brandGreen)
                        .font(.system(size: 12))
                    Text("GoFit")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Water Ring
                ZStack {
                    Circle()
                        .stroke(brandGreen.opacity(0.15), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: min(conn.waterLiters / max(conn.waterGoal, 0.1), 1.0))
                        .stroke(
                            AngularGradient(
                                colors: [brandBlue, brandGreen],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 1) {
                        Text("💧")
                            .font(.system(size: 18))
                        Text(String(format: "%.1fL", conn.waterLiters))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("/ \(String(format: "%.1fL", conn.waterGoal))")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 100, height: 100)
                
                // Stats
                HStack(spacing: 16) {
                    statBubble(icon: "flame.fill", color: .orange, value: "\(Int(conn.calories))", label: "cal")
                    statBubble(icon: "figure.walk", color: .yellow, value: "\(conn.steps)", label: "steps")
                }
                
                HStack(spacing: 16) {
                    statBubble(icon: "fork.knife", color: brandGreen, value: "\(conn.mealCount)", label: "meals")
                    statBubble(icon: "bolt.fill", color: brandBlue, value: "\(Int(conn.protein))g", label: "protein")
                }
                
                // Quick Actions
                HStack(spacing: 8) {
                    Button {
                        conn.logWater(250)
                    } label: {
                        Label("250ml", systemImage: "drop.fill")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(brandBlue)
                    
                    Button {
                        conn.logWater(500)
                    } label: {
                        Label("500ml", systemImage: "drop.fill")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(brandGreen)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private func statBubble(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
    }
}

// MARK: - Water View
struct WatchWaterView: View {
    @EnvironmentObject var conn: WatchConnectivityManager
    @State private var showConfirmation = false
    @State private var lastLogged = 0
    
    private let brandGreen = Color(red: 0.2, green: 0.85, blue: 0.4)
    private let brandBlue = Color(red: 0.3, green: 0.6, blue: 1.0)
    
    private let presets: [(String, Int, String)] = [
        ("Sip", 100, "drop"),
        ("Glass", 250, "drop.fill"),
        ("Bottle", 500, "waterbottle"),
        ("Big", 750, "waterbottle.fill"),
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("💧 Log Water")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Preset buttons
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(presets, id: \.1) { preset in
                        Button {
                            conn.logWater(preset.1)
                            lastLogged = preset.1
                            showConfirmation = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showConfirmation = false
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: preset.2)
                                    .font(.system(size: 14))
                                Text("\(preset.1)ml")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                Text(preset.0)
                                    .font(.system(size: 8))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .tint(brandBlue)
                    }
                }
                
                // Total
                Text(String(format: "Total: %.1fL / %.1fL", conn.waterLiters, conn.waterGoal))
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 4)
        }
        .overlay {
            if showConfirmation {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(brandGreen)
                    Text("+\(lastLogged)ml")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showConfirmation)
            }
        }
    }
}

// MARK: - Quick Log View
struct WatchQuickLogView: View {
    @EnvironmentObject var conn: WatchConnectivityManager
    @State private var showConfirmation = false
    @State private var lastFood = ""
    
    private let brandGreen = Color(red: 0.2, green: 0.85, blue: 0.4)
    
    private let quickFoods: [(String, String, Double)] = [
        ("🍌", "Banana", 105),
        ("🍎", "Apple", 95),
        ("🥚", "Egg", 78),
        ("🍞", "Toast", 120),
        ("🥗", "Salad", 180),
        ("🍗", "Chicken", 250),
        ("🍚", "Rice", 200),
        ("☕", "Coffee", 5),
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("🍽️ Quick Log")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(quickFoods, id: \.1) { food in
                        Button {
                            conn.logQuickMeal(name: food.1, calories: food.2)
                            lastFood = food.1
                            showConfirmation = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showConfirmation = false
                            }
                        } label: {
                            VStack(spacing: 1) {
                                Text(food.0)
                                    .font(.system(size: 16))
                                Text(food.1)
                                    .font(.system(size: 9, weight: .medium))
                                Text("\(Int(food.2)) cal")
                                    .font(.system(size: 7))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(brandGreen)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .overlay {
            if showConfirmation {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(brandGreen)
                    Text("Logged \(lastFood)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: showConfirmation)
            }
        }
    }
}
