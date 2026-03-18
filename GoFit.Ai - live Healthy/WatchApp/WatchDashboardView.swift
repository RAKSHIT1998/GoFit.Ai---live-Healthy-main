#if os(watchOS)
import SwiftUI

struct WatchDashboardView: View {
    @StateObject private var watchManager = WatchConnectivityManager.shared
    @State private var animateRing = false
    
    private let brandGreen = Color(red: 0.2, green: 0.85, blue: 0.4)
    private let brandBlue = Color(red: 0.3, green: 0.6, blue: 1.0)
    
    var waterProgress: Double {
        guard watchManager.nutrition.water > 0 else { return 0 }
        return min(watchManager.nutrition.water / 2.0, 1.0) // 2L goal
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // MARK: - Header
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(brandGreen)
                        .font(.system(size: 12))
                    Text("GoFit")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Text(timeString)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 4)
                
                // MARK: - Water Ring (hero element)
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(brandGreen.opacity(0.15), lineWidth: 12)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: animateRing ? waterProgress : 0)
                        .stroke(
                            AngularGradient(
                                colors: [brandBlue, brandGreen, brandGreen.opacity(0.8)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.2, dampingFraction: 0.8), value: animateRing)
                    
                    // Center content
                    VStack(spacing: 2) {
                        Text("💧")
                            .font(.system(size: 20))
                        Text(String(format: "%.1fL", watchManager.nutrition.water))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("/ 2.0L")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 100, height: 100)
                .padding(.vertical, 4)
                
                // MARK: - Quick Stats
                HStack(spacing: 12) {
                    statBubble(
                        icon: "flame.fill",
                        color: .orange,
                        value: "\(Int(watchManager.nutrition.calories))",
                        unit: "cal"
                    )
                    statBubble(
                        icon: "figure.strengthtraining.traditional",
                        color: brandGreen,
                        value: String(format: "%.0f", watchManager.nutrition.protein),
                        unit: "g pro"
                    )
                }
                
                HStack(spacing: 12) {
                    statBubble(
                        icon: "leaf.arrow.circlepath",
                        color: .yellow,
                        value: String(format: "%.0f", watchManager.nutrition.carbs),
                        unit: "g carb"
                    )
                    statBubble(
                        icon: "drop.triangle.fill",
                        color: .pink,
                        value: String(format: "%.0f", watchManager.nutrition.fat),
                        unit: "g fat"
                    )
                }
                
                // MARK: - Quick Actions
                Divider()
                    .padding(.vertical, 4)
                
                Button {
                    watchManager.logWater(amount: 0.25)
                    WatchHaptic.play(.success)
                } label: {
                    Label("Log 250ml Water", systemImage: "drop.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(brandBlue)
                
                Button {
                    watchManager.openScannerOnPhone()
                    WatchHaptic.play(.click)
                } label: {
                    Label("Scan Food (iPhone)", systemImage: "camera.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(brandGreen)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .onAppear {
            watchManager.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                animateRing = true
            }
        }
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private func statBubble(icon: String, color: Color, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(unit)
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: Date())
    }
}

// MARK: - Watch Haptics
enum WatchHaptic {
    case success, click, failure
    
    static func play(_ type: WatchHaptic) {
        switch type {
        case .success:
            WKInterfaceDevice.current().play(.success)
        case .click:
            WKInterfaceDevice.current().play(.click)
        case .failure:
            WKInterfaceDevice.current().play(.failure)
        }
    }
}
#endif
