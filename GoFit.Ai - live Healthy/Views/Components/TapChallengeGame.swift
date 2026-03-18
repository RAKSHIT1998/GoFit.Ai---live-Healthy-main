//
//  TapChallengeGame.swift
//  GoFit.Ai - live Healthy
//
//  Quick tap-based mini game for bonus XP - fun fitness-themed reflex challenge
//

import SwiftUI

// MARK: - Tap Challenge Game
struct TapChallengeGame: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var score = 0
    @State private var timeRemaining = 15.0
    @State private var isPlaying = false
    @State private var gameOver = false
    @State private var targets: [TapTarget] = []
    @State private var combo = 0
    @State private var maxCombo = 0
    @State private var showComboText = false
    @State private var comboTextScale: CGFloat = 0
    @State private var screenFlash = false
    @State private var missShake = false
    
    let timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()
    let targetTimer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Background
            (gameOver ? Color.black : Design.Colors.background)
                .ignoresSafeArea()
                .opacity(screenFlash ? 0.8 : 1)
            
            if !isPlaying && !gameOver {
                // Start screen
                startScreen
            } else if isPlaying {
                // Game screen
                gameScreen
            } else {
                // Results screen
                resultsScreen
            }
        }
    }
    
    // MARK: - Start Screen
    private var startScreen: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Text("⚡️")
                .font(.system(size: 80))
                .floating(amount: 8, duration: 1.5)
            
            Text("Tap Challenge!")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Text("Tap the fitness emojis as fast as you can!\nAvoid the ❌ targets!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: Design.Spacing.sm) {
                HStack(spacing: Design.Spacing.md) {
                    GameInfoPill(emoji: "⏱️", text: "15 seconds")
                    GameInfoPill(emoji: "🎯", text: "Tap targets")
                    GameInfoPill(emoji: "🔥", text: "Build combos")
                }
            }
            
            Spacer()
            
            Button {
                HapticManager.shared.mediumTap()
                startGame()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "play.fill")
                        .font(.title3)
                    Text("START GAME")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(colors: [Design.Colors.primary, Design.Colors.primaryLight], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(20)
                .shadow(color: Design.Colors.primary.opacity(0.4), radius: 10)
            }
            .padding(.horizontal, 30)
            
            Button {
                dismiss()
            } label: {
                Text("Maybe Later")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Game Screen
    private var gameScreen: some View {
        ZStack {
            // Targets
            ForEach(targets) { target in
                TapTargetView(target: target) {
                    tapTarget(target)
                }
            }
            
            // HUD
            VStack {
                HStack {
                    // Score
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("\(score)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    
                    Spacer()
                    
                    // Combo
                    if combo > 1 {
                        HStack(spacing: 4) {
                            Text("🔥")
                            Text("\(combo)x COMBO")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.2))
                        .cornerRadius(12)
                        .scaleEffect(comboTextScale)
                        .transition(.scale)
                    }
                    
                    Spacer()
                    
                    // Timer
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(timeRemaining < 5 ? .red : Design.Colors.primary)
                        Text(String(format: "%.1f", timeRemaining))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(timeRemaining < 5 ? .red : .primary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.top, 60)
                
                Spacer()
            }
        }
        .onReceive(timer) { _ in
            if isPlaying {
                timeRemaining -= 0.01
                if timeRemaining <= 0 {
                    endGame()
                }
            }
        }
        .onReceive(targetTimer) { _ in
            if isPlaying {
                spawnTarget()
            }
        }
    }
    
    // MARK: - Results Screen
    private var resultsScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text(resultEmoji())
                .font(.system(size: 80))
            
            Text(resultTitle())
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Stats
            VStack(spacing: Design.Spacing.md) {
                ResultStatRow(label: "Score", value: "\(score)", emoji: "⭐️")
                ResultStatRow(label: "Max Combo", value: "\(maxCombo)x", emoji: "🔥")
                ResultStatRow(label: "XP Earned", value: "+\(xpEarned())", emoji: "💎")
            }
            .padding(Design.Spacing.lg)
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)
            .padding(.horizontal, 30)
            
            Spacer()
            
            VStack(spacing: Design.Spacing.md) {
                Button {
                    HapticManager.shared.mediumTap()
                    resetGame()
                    startGame()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Play Again")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Design.Colors.primaryGradient)
                    .cornerRadius(16)
                }
                
                Button {
                    dismiss()
                } label: {
                    Text("Collect \(xpEarned()) XP & Exit")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 40)
        }
        .onAppear {
            // Award XP
            let xp = xpEarned()
            if xp > 0 {
                RewardEngine.shared.awardXP(xp, reason: "Tap Challenge! Score: \(score)")
            }
        }
    }
    
    // MARK: - Game Logic
    
    private func startGame() {
        resetGame()
        isPlaying = true
        // Spawn initial targets
        for _ in 0..<3 {
            spawnTarget()
        }
    }
    
    private func resetGame() {
        score = 0
        timeRemaining = 15.0
        gameOver = false
        isPlaying = false
        targets = []
        combo = 0
        maxCombo = 0
    }
    
    private func spawnTarget() {
        // Remove old targets
        targets.removeAll { $0.spawnedAt.timeIntervalSinceNow < -2.0 }
        
        guard targets.count < 5 else { return }
        
        let screenWidth = UIScreen.main.bounds.width - 80
        let screenHeight = UIScreen.main.bounds.height - 200
        
        let isBad = Int.random(in: 1...5) == 1 // 20% chance of bad target
        
        let target = TapTarget(
            position: CGPoint(
                x: CGFloat.random(in: 40...screenWidth),
                y: CGFloat.random(in: 120...screenHeight)
            ),
            emoji: isBad ? "❌" : randomFitnessEmoji(),
            isBad: isBad,
            points: isBad ? -20 : (Int.random(in: 1...3) * 10),
            size: CGFloat.random(in: 44...60)
        )
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            targets.append(target)
        }
    }
    
    private func tapTarget(_ target: TapTarget) {
        guard isPlaying else { return }
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            targets.removeAll { $0.id == target.id }
        }
        
        if target.isBad {
            // Hit bad target
            HapticManager.shared.lightTap()
            combo = 0
            score = max(0, score - 20)
            withAnimation(.linear(duration: 0.1)) {
                screenFlash = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                screenFlash = false
            }
        } else {
            // Hit good target
            HapticManager.shared.success()
            combo += 1
            maxCombo = max(maxCombo, combo)
            
            let comboMultiplier = min(combo, 5)
            let points = target.points * comboMultiplier
            score += points
            
            // Show combo
            withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                comboTextScale = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring()) {
                    comboTextScale = 1.0
                }
            }
        }
        
        // Spawn replacement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if isPlaying { spawnTarget() }
        }
    }
    
    private func endGame() {
        isPlaying = false
        gameOver = true
        HapticManager.shared.success()
    }
    
    private func randomFitnessEmoji() -> String {
        ["💪", "🏃", "🏋️", "🧘", "🚴", "⚡️", "🎯", "🌟", "🍎", "💧", "🥦", "🏆"].randomElement() ?? "⭐️"
    }
    
    private func xpEarned() -> Int {
        let baseXP = score / 5
        let comboBonus = maxCombo * 2
        return max(5, baseXP + comboBonus)
    }
    
    private func resultEmoji() -> String {
        switch score {
        case 0..<50: return "🌱"
        case 50..<100: return "💪"
        case 100..<200: return "🔥"
        case 200..<300: return "⚡️"
        default: return "👑"
        }
    }
    
    private func resultTitle() -> String {
        switch score {
        case 0..<50: return "Good Start!"
        case 50..<100: return "Nice Work!"
        case 100..<200: return "Impressive!"
        case 200..<300: return "Amazing!"
        default: return "LEGENDARY!"
        }
    }
}

// MARK: - Tap Target Model
struct TapTarget: Identifiable {
    let id = UUID()
    let position: CGPoint
    let emoji: String
    let isBad: Bool
    let points: Int
    let size: CGFloat
    let spawnedAt = Date()
}

// MARK: - Tap Target View
struct TapTargetView: View {
    let target: TapTarget
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 0
    @State private var pulse = false
    @State private var opacity: Double = 1
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Glow
                Circle()
                    .fill(target.isBad ? Color.red.opacity(0.2) : Design.Colors.primary.opacity(0.2))
                    .frame(width: target.size + 20, height: target.size + 20)
                    .scaleEffect(pulse ? 1.2 : 1.0)
                
                // Target
                Text(target.emoji)
                    .font(.system(size: target.size * 0.6))
                    .frame(width: target.size, height: target.size)
                    .background(
                        Circle()
                            .fill(target.isBad ?
                                  Color.red.opacity(0.15) :
                                    Design.Colors.primary.opacity(0.15))
                    )
            }
        }
        .buttonStyle(.plain)
        .position(target.position)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scale = 1.0
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
            // Auto-disappear after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 0
                    scale = 0.3
                }
            }
        }
    }
}

// MARK: - Game Info Pill
struct GameInfoPill: View {
    let emoji: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
                .font(.caption)
            Text(text)
                .font(.caption2.weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Design.Colors.cardBackground)
        .cornerRadius(10)
    }
}

// MARK: - Result Stat Row
struct ResultStatRow: View {
    let label: String
    let value: String
    let emoji: String
    
    var body: some View {
        HStack {
            Text(emoji)
                .font(.title3)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Dashboard Game Card
struct MiniGameCard: View {
    @State private var showingGame = false
    @State private var bounceEmoji = false
    
    var body: some View {
        Button {
            HapticManager.shared.mediumTap()
            showingGame = true
        } label: {
            HStack(spacing: Design.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Text("🎮")
                        .font(.system(size: 26))
                        .offset(y: bounceEmoji ? -3 : 3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tap Challenge")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Quick game for bonus XP! ⚡️")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("PLAY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                    )
            }
            .padding(Design.Spacing.lg)
            .background(Design.Colors.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showingGame) {
            TapChallengeGame()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                bounceEmoji = true
            }
        }
    }
}
