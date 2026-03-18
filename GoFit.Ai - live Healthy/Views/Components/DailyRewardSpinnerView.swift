//
//  DailyRewardSpinnerView.swift
//  GoFit.Ai - live Healthy
//
//  Fun daily reward spinner wheel for bonus XP and power-ups
//

import SwiftUI

// MARK: - Reward Slot Model
struct SpinnerReward: Identifiable {
    let id = UUID()
    let emoji: String
    let title: String
    let xp: Int
    let color: Color
    let rarity: RewardRarity
    
    enum RewardRarity: String {
        case common, uncommon, rare, epic, legendary
        
        var glowColor: Color {
            switch self {
            case .common: return .gray
            case .uncommon: return .green
            case .rare: return .blue
            case .epic: return .purple
            case .legendary: return .orange
            }
        }
        
        var label: String {
            switch self {
            case .common: return "Common"
            case .uncommon: return "Uncommon"
            case .rare: return "Rare!"
            case .epic: return "EPIC!"
            case .legendary: return "✨ LEGENDARY ✨"
            }
        }
    }
    
    static let allRewards: [SpinnerReward] = [
        SpinnerReward(emoji: "⭐️", title: "+10 XP", xp: 10, color: .yellow, rarity: .common),
        SpinnerReward(emoji: "💪", title: "+15 XP", xp: 15, color: .orange, rarity: .common),
        SpinnerReward(emoji: "🔥", title: "+25 XP", xp: 25, color: .red, rarity: .uncommon),
        SpinnerReward(emoji: "💎", title: "+50 XP", xp: 50, color: .cyan, rarity: .rare),
        SpinnerReward(emoji: "🛡️", title: "Streak Shield", xp: 30, color: .blue, rarity: .uncommon),
        SpinnerReward(emoji: "⚡️", title: "2x Points (1hr)", xp: 20, color: .purple, rarity: .rare),
        SpinnerReward(emoji: "🏆", title: "+75 XP", xp: 75, color: .yellow, rarity: .epic),
        SpinnerReward(emoji: "👑", title: "+100 XP", xp: 100, color: .orange, rarity: .legendary),
        SpinnerReward(emoji: "🎯", title: "+20 XP", xp: 20, color: .green, rarity: .common),
        SpinnerReward(emoji: "🚀", title: "+35 XP", xp: 35, color: .mint, rarity: .uncommon),
        SpinnerReward(emoji: "🌟", title: "+40 XP", xp: 40, color: .indigo, rarity: .rare),
        SpinnerReward(emoji: "💥", title: "+60 XP Burst!", xp: 60, color: .pink, rarity: .epic),
    ]
    
    static func weightedRandom() -> SpinnerReward {
        // Weighted: common 40%, uncommon 30%, rare 18%, epic 9%, legendary 3%
        let roll = Int.random(in: 1...100)
        let rarity: RewardRarity
        switch roll {
        case 1...40: rarity = .common
        case 41...70: rarity = .uncommon
        case 71...88: rarity = .rare
        case 89...97: rarity = .epic
        default: rarity = .legendary
        }
        return allRewards.filter { $0.rarity == rarity }.randomElement() ?? allRewards[0]
    }
}

// MARK: - Daily Reward Manager
@MainActor
class DailyRewardManager: ObservableObject {
    static let shared = DailyRewardManager()
    
    @Published var canSpin: Bool = true
    @Published var lastReward: SpinnerReward? = nil
    @Published var spinStreak: Int = 0
    
    private let lastSpinKey = "daily_spin_date"
    private let spinStreakKey = "daily_spin_streak"
    
    private init() {
        checkSpinAvailability()
    }
    
    func checkSpinAvailability() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastSpin = UserDefaults.standard.object(forKey: lastSpinKey) as? Date {
            let lastSpinDay = calendar.startOfDay(for: lastSpin)
            canSpin = lastSpinDay != today
            
            // Check spin streak
            let daysDiff = calendar.dateComponents([.day], from: lastSpinDay, to: today).day ?? 0
            if daysDiff > 1 {
                spinStreak = 0
                UserDefaults.standard.set(0, forKey: spinStreakKey)
            } else {
                spinStreak = UserDefaults.standard.integer(forKey: spinStreakKey)
            }
        } else {
            canSpin = true
            spinStreak = 0
        }
    }
    
    func recordSpin(reward: SpinnerReward) {
        let today = Calendar.current.startOfDay(for: Date())
        UserDefaults.standard.set(today, forKey: lastSpinKey)
        
        spinStreak += 1
        UserDefaults.standard.set(spinStreak, forKey: spinStreakKey)
        
        canSpin = false
        lastReward = reward
        
        // Award XP
        RewardEngine.shared.awardXP(reward.xp, reason: "Daily Spin: \(reward.title)")
    }
}

// MARK: - Spinner Wheel View
struct DailyRewardSpinnerView: View {
    @ObservedObject var manager = DailyRewardManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var wonReward: SpinnerReward? = nil
    @State private var showRewardCard = false
    @State private var sparklePhase = false
    @State private var pointerBounce = false
    
    let slotCount = 8
    private var displayRewards: [SpinnerReward] {
        Array(SpinnerReward.allRewards.shuffled().prefix(slotCount))
    }
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.black,
                    Design.Colors.primaryDark.opacity(0.8),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            // Sparkle particles
            SpinnerParticles(isActive: isSpinning || showRewardCard)
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    
                    // Spin streak
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("\(manager.spinStreak) day spin streak")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                Text("Daily Reward")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Spin to win XP & power-ups!")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                // Wheel
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                center: .center
                            ),
                            lineWidth: 6
                        )
                        .frame(width: 290, height: 290)
                        .blur(radius: isSpinning ? 4 : 1)
                        .opacity(isSpinning ? 0.9 : 0.5)
                    
                    // Wheel segments
                    ZStack {
                        ForEach(0..<slotCount, id: \.self) { index in
                            WheelSegment(
                                index: index,
                                total: slotCount,
                                reward: displayRewards[index]
                            )
                        }
                    }
                    .frame(width: 270, height: 270)
                    .clipShape(Circle())
                    .rotationEffect(.degrees(rotation))
                    .shadow(color: .black.opacity(0.5), radius: 20)
                    
                    // Center hub
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white, Color.gray.opacity(0.3)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: .black.opacity(0.3), radius: 6)
                        .overlay(
                            Image(systemName: "star.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                        )
                    
                    // Pointer at top
                    VStack(spacing: 0) {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .shadow(color: .orange, radius: isSpinning ? 8 : 3)
                            .offset(y: pointerBounce ? -4 : 0)
                        Spacer()
                    }
                    .frame(height: 310)
                }
                
                Spacer()
                
                // Spin Button
                Button {
                    spin()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: manager.canSpin ? "sparkles" : "clock.fill")
                            .font(.title3)
                        Text(manager.canSpin ? "SPIN!" : "Come Back Tomorrow!")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        manager.canSpin ?
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(20)
                    .shadow(color: manager.canSpin ? .orange.opacity(0.5) : .clear, radius: 10)
                }
                .disabled(!manager.canSpin || isSpinning)
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
            
            // Reward Reveal Overlay
            if showRewardCard, let reward = wonReward {
                RewardRevealCard(reward: reward) {
                    withAnimation(.spring()) {
                        showRewardCard = false
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                pointerBounce = true
            }
        }
    }
    
    private func spin() {
        guard manager.canSpin, !isSpinning else { return }
        
        HapticManager.shared.mediumTap()
        isSpinning = true
        
        // Pick reward
        let reward = SpinnerReward.weightedRandom()
        wonReward = reward
        
        // Calculate target rotation (multiple full spins + landing angle)
        let targetSegmentIndex = SpinnerReward.allRewards.firstIndex(where: { $0.emoji == reward.emoji }) ?? 0
        let segmentAngle = 360.0 / Double(slotCount)
        let targetAngle = 360 * 5 + (360 - Double(targetSegmentIndex) * segmentAngle)
        
        // Haptic ticks during spin
        spinHapticFeedback()
        
        withAnimation(.easeOut(duration: 4.0)) {
            rotation += targetAngle
        }
        
        // Show reward after spin completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            isSpinning = false
            manager.recordSpin(reward: reward)
            HapticManager.shared.success()
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showRewardCard = true
            }
        }
    }
    
    private func spinHapticFeedback() {
        // Tick sounds during spin
        for i in 0..<20 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                if isSpinning {
                    HapticManager.shared.lightTap()
                }
            }
        }
    }
}

// MARK: - Wheel Segment
struct WheelSegment: View {
    let index: Int
    let total: Int
    let reward: SpinnerReward
    
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2
            let startAngle = Angle.degrees(Double(index) / Double(total) * 360 - 90)
            let endAngle = Angle.degrees(Double(index + 1) / Double(total) * 360 - 90)
            let midAngle = Angle.degrees((startAngle.degrees + endAngle.degrees) / 2)
            
            // Segment path
            Path { path in
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                path.closeSubpath()
            }
            .fill(
                index % 2 == 0 ?
                LinearGradient(colors: [reward.color.opacity(0.8), reward.color.opacity(0.5)], startPoint: .top, endPoint: .bottom) :
                    LinearGradient(colors: [reward.color.opacity(0.5), reward.color.opacity(0.3)], startPoint: .top, endPoint: .bottom)
            )
            
            // Emoji label
            let labelRadius = radius * 0.65
            let labelX = center.x + labelRadius * cos(CGFloat(midAngle.radians))
            let labelY = center.y + labelRadius * sin(CGFloat(midAngle.radians))
            
            Text(reward.emoji)
                .font(.system(size: 28))
                .position(x: labelX, y: labelY)
                .rotationEffect(midAngle + .degrees(90))
        }
    }
}

// MARK: - Reward Reveal Card
struct RewardRevealCard: View {
    let reward: SpinnerReward
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0.3
    @State private var emojiScale: CGFloat = 0
    @State private var showDetails = false
    @State private var sparkle = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }
            
            VStack(spacing: 20) {
                // Rarity label
                Text(reward.rarity.label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(reward.rarity.glowColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(reward.rarity.glowColor.opacity(0.2))
                    .cornerRadius(12)
                    .opacity(showDetails ? 1 : 0)
                
                // Giant emoji
                Text(reward.emoji)
                    .font(.system(size: 80))
                    .scaleEffect(emojiScale)
                    .shadow(color: reward.rarity.glowColor.opacity(0.8), radius: sparkle ? 30 : 10)
                
                // Title
                Text(reward.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(showDetails ? 1 : 0)
                
                // XP amount
                Text("+\(reward.xp) XP")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(showDetails ? 1 : 0)
                
                Button(action: onDismiss) {
                    Text("Collect! 🎉")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Design.Colors.primary, Design.Colors.primaryLight],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                }
                .opacity(showDetails ? 1 : 0)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color(white: 0.12))
                    .shadow(color: reward.rarity.glowColor.opacity(0.4), radius: 30)
            )
            .scaleEffect(scale)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                scale = 1.0
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.4).delay(0.3)) {
                emojiScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.6)) {
                showDetails = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
                sparkle = true
            }
        }
    }
}

// MARK: - Spinner Particles
struct SpinnerParticles: View {
    let isActive: Bool
    @State private var particles: [(CGPoint, Color, CGFloat)] = []
    @State private var animate = false
    
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<30, id: \.self) { i in
                Circle()
                    .fill(
                        [Color.yellow, .orange, .cyan, .pink, .purple, .green]
                            .randomElement() ?? .white
                    )
                    .frame(width: CGFloat.random(in: 2...6))
                    .position(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: animate ? CGFloat.random(in: 0...geo.size.height) : -10
                    )
                    .opacity(isActive ? Double.random(in: 0.3...0.8) : 0)
                    .animation(
                        .easeInOut(duration: Double.random(in: 2...5))
                        .repeatForever(autoreverses: true)
                        .delay(Double.random(in: 0...2)),
                        value: animate
                    )
            }
        }
        .onAppear {
            animate = true
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Dashboard Compact Spinner Card
struct DailySpinnerCard: View {
    @ObservedObject var manager = DailyRewardManager.shared
    @State private var showingSpinner = false
    @State private var pulseGlow = false
    @State private var rotateIcon = false
    
    var body: some View {
        Button {
            HapticManager.shared.mediumTap()
            showingSpinner = true
        } label: {
            HStack(spacing: Design.Spacing.md) {
                // Animated gift icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: manager.canSpin ? [.orange, .red] : [.gray.opacity(0.3), .gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                        .shadow(color: manager.canSpin ? .orange.opacity(0.5) : .clear, radius: pulseGlow ? 12 : 6)
                    
                    Text(manager.canSpin ? "🎰" : "✅")
                        .font(.system(size: 26))
                        .rotationEffect(.degrees(rotateIcon ? 10 : -10))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(manager.canSpin ? "Daily Reward!" : "Claimed Today")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                    
                    if manager.canSpin {
                        Text("Tap to spin & win XP! 🎉")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let reward = manager.lastReward {
                        Text("Won: \(reward.emoji) \(reward.title)")
                            .font(.caption)
                            .foregroundColor(Design.Colors.primary)
                    } else {
                        Text("Come back tomorrow for more!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if manager.canSpin {
                    // Animated NEW badge
                    Text("SPIN")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                        )
                        .scaleEffect(pulseGlow ? 1.1 : 1.0)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Design.Colors.primary)
                        .font(.title3)
                }
            }
            .padding(Design.Spacing.lg)
            .background(Design.Colors.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingSpinner) {
            DailyRewardSpinnerView()
        }
        .onAppear {
            if manager.canSpin {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseGlow = true
                }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    rotateIcon = true
                }
            }
        }
    }
}
