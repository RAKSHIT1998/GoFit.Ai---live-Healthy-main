#if os(watchOS)
import SwiftUI
import WatchConnectivity

// MARK: - Watch Water View
/// Dedicated water logging screen with quick-tap buttons for different amounts
struct WatchWaterView: View {
    @StateObject private var watchManager = WatchConnectivityManager.shared
    @State private var showConfirmation = false
    @State private var lastLogged = ""
    
    private let brandBlue = Color(red: 0.3, green: 0.6, blue: 1.0)
    private let brandGreen = Color(red: 0.2, green: 0.85, blue: 0.4)
    
    let presets: [(name: String, emoji: String, ml: Int, color: Color)] = [
        ("Glass", "🥛", 250, Color(red: 0.3, green: 0.6, blue: 1.0)),
        ("Bottle", "🍶", 500, Color(red: 0.2, green: 0.85, blue: 0.4)),
        ("Big Bottle", "💧", 750, Color(red: 0.4, green: 0.7, blue: 1.0)),
        ("1 Liter", "🫗", 1000, Color(red: 0.1, green: 0.7, blue: 0.3)),
        ("Sip", "💦", 100, .gray),
        ("Coffee", "☕", 250, .brown),
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Header
                Text("💧 Log Water")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Current intake
                Text(String(format: "%.1fL today", watchManager.nutrition.water))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                
                // Preset buttons
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(presets, id: \.name) { preset in
                        Button {
                            logWater(preset)
                        } label: {
                            VStack(spacing: 4) {
                                Text(preset.emoji)
                                    .font(.system(size: 20))
                                Text("\(preset.ml)ml")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text(preset.name)
                                    .font(.system(size: 9))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(preset.color.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 16)
        }
        .overlay {
            if showConfirmation {
                confirmationOverlay
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var confirmationOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(brandGreen)
            Text(lastLogged)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
    
    private func logWater(_ preset: (name: String, emoji: String, ml: Int, color: Color)) {
        let liters = Double(preset.ml) / 1000.0
        watchManager.logWater(amount: liters)
        WatchHaptic.play(.success)
        
        lastLogged = "\(preset.emoji) +\(preset.ml)ml"
        withAnimation(.spring()) { showConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { showConfirmation = false }
        }
    }
}

// MARK: - Watch Quick Log View
/// Quick buttons to open scanner or log common items from the watch
struct WatchQuickLogView: View {
    @StateObject private var watchManager = WatchConnectivityManager.shared
    
    private let brandGreen = Color(red: 0.2, green: 0.85, blue: 0.4)
    
    let quickFoods: [(name: String, emoji: String, cal: Int)] = [
        ("Banana", "🍌", 105),
        ("Apple", "🍎", 95),
        ("Coffee", "☕", 5),
        ("Protein Shake", "🥤", 200),
        ("Salad", "🥗", 120),
        ("Sandwich", "🥪", 350),
        ("Egg", "🥚", 78),
        ("Rice Bowl", "🍚", 250),
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("🍽️ Quick Log")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                // Scan on iPhone
                Button {
                    watchManager.openScannerOnPhone()
                    WatchHaptic.play(.click)
                } label: {
                    HStack {
                        Image(systemName: "camera.fill")
                        Text("Scan on iPhone")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(brandGreen)
                
                Divider()
                    .padding(.vertical, 2)
                
                Text("Quick Items")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                
                // Quick food buttons
                ForEach(quickFoods, id: \.name) { food in
                    Button {
                        logQuickFood(food)
                    } label: {
                        HStack {
                            Text(food.emoji)
                                .font(.system(size: 16))
                            Text(food.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(food.cal) cal")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 16)
        }
    }
    
    private func logQuickFood(_ food: (name: String, emoji: String, cal: Int)) {
        // Send to iPhone to log the meal
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage([
            "action": "logQuickMeal",
            "name": food.name,
            "calories": food.cal
        ], replyHandler: nil, errorHandler: nil)
        WatchHaptic.play(.success)
    }
}
#endif
