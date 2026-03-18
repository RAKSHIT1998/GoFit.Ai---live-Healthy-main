//
//  FitnessMascotView.swift
//  GoFit.Ai - live Healthy
//
//  An animated mascot character that reacts to user progress and provides encouragement
//

import SwiftUI

// MARK: - Mascot State
enum MascotMood {
    case idle
    case happy
    case cheering
    case sleeping
    case exercising
    case eating
    case celebrating
    
    var bodyEmoji: String {
        switch self {
        case .idle: return "🤖"
        case .happy: return "😄"
        case .cheering: return "🎉"
        case .sleeping: return "😴"
        case .exercising: return "💪"
        case .eating: return "🍽️"
        case .celebrating: return "🥳"
        }
    }
    
    var message: String {
        switch self {
        case .idle:
            let messages = [
                "Ready for action! 🚀",
                "What's the plan today? 🤔",
                "Let's crush some goals! 💫",
                "I believe in you! ✨"
            ]
            return messages.randomElement() ?? messages[0]
        case .happy:
            return "You're doing great! Keep it up! 🌟"
        case .cheering:
            return "WOOOO! Amazing progress! 🎊"
        case .sleeping:
            return "Zzz... Rest up for tomorrow! 💤"
        case .exercising:
            return "Feel the burn! You're getting stronger! 🔥"
        case .eating:
            return "Fueling up for greatness! 🍏"
        case .celebrating:
            return "GOAL ACHIEVED! You're a legend! 👑"
        }
    }
}

// MARK: - Animated Mascot
struct FitnessMascotView: View {
    @ObservedObject var streakManager = StreakManager.shared
    @State private var mascotMood: MascotMood = .idle
    @State private var bounce = false
    @State private var waveArm = false
    @State private var showSpeechBubble = false
    @State private var eyeBlink = false
    @State private var bodyRotation: Double = 0
    
    var body: some View {
        HStack(spacing: Design.Spacing.md) {
            // Mascot character
            ZStack {
                // Body glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Design.Colors.primary.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                    .scaleEffect(bounce ? 1.1 : 0.95)
                
                // Mascot body
                VStack(spacing: -2) {
                    // Face
                    ZStack {
                        // Head
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Design.Colors.primary, Design.Colors.primaryLight],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .shadow(color: Design.Colors.primary.opacity(0.4), radius: 8)
                        
                        // Eyes
                        HStack(spacing: 12) {
                            // Left eye
                            Capsule()
                                .fill(.white)
                                .frame(width: 10, height: eyeBlink ? 2 : 10)
                                .overlay(
                                    Circle()
                                        .fill(.black)
                                        .frame(width: 5, height: 5)
                                        .opacity(eyeBlink ? 0 : 1)
                                )
                            
                            // Right eye
                            Capsule()
                                .fill(.white)
                                .frame(width: 10, height: eyeBlink ? 2 : 10)
                                .overlay(
                                    Circle()
                                        .fill(.black)
                                        .frame(width: 5, height: 5)
                                        .opacity(eyeBlink ? 0 : 1)
                                )
                        }
                        .offset(y: -4)
                        
                        // Mouth
                        mouthView
                            .offset(y: 10)
                        
                        // Accessories based on level
                        if streakManager.level >= 10 {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                                .offset(y: -30)
                                .shadow(color: .yellow.opacity(0.5), radius: 4)
                        } else if streakManager.level >= 5 {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                                .offset(x: 22, y: -18)
                        }
                    }
                    
                    // Arms (waving)
                    HStack(spacing: 30) {
                        // Left arm
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Design.Colors.primary)
                            .frame(width: 8, height: 20)
                            .rotationEffect(.degrees(waveArm ? -30 : 10), anchor: .top)
                        
                        // Right arm
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Design.Colors.primary)
                            .frame(width: 8, height: 20)
                            .rotationEffect(.degrees(waveArm ? 30 : -10), anchor: .top)
                    }
                    .offset(y: -6)
                }
                .offset(y: bounce ? -6 : 0)
                .rotationEffect(.degrees(bodyRotation))
            }
            
            // Speech bubble
            if showSpeechBubble {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mascotMood.message)
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Level indicator
                    HStack(spacing: 4) {
                        Text("Lv.\(streakManager.level)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Design.Colors.primary)
                        Text(streakManager.levelTitle)
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Design.Colors.cardBackground)
                        .shadow(color: Color.primary.opacity(0.08), radius: 4)
                )
                .transition(.scale(scale: 0.5, anchor: .leading).combined(with: .opacity))
            }
        }
        .onAppear {
            updateMascotMood()
            startAnimations()
        }
    }
    
    @ViewBuilder
    private var mouthView: some View {
        switch mascotMood {
        case .happy, .cheering, .celebrating:
            // Happy smile
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(to: CGPoint(x: 16, y: 0), control: CGPoint(x: 8, y: 8))
            }
            .stroke(Color.white, lineWidth: 2)
            .frame(width: 16, height: 10)
        case .sleeping:
            // Zzz mouth
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.5))
                .frame(width: 12, height: 3)
        case .exercising:
            // Determined grin
            Path { path in
                path.move(to: CGPoint(x: 0, y: 2))
                path.addQuadCurve(to: CGPoint(x: 18, y: 2), control: CGPoint(x: 9, y: 10))
            }
            .stroke(Color.white, lineWidth: 2.5)
            .frame(width: 18, height: 12)
        default:
            // Neutral smile
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(to: CGPoint(x: 14, y: 0), control: CGPoint(x: 7, y: 5))
            }
            .stroke(Color.white, lineWidth: 2)
            .frame(width: 14, height: 8)
        }
    }
    
    private func updateMascotMood() {
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour >= 23 || hour < 6 {
            mascotMood = .sleeping
        } else if streakManager.todayPoints >= 100 {
            mascotMood = .celebrating
        } else if streakManager.currentStreak >= 7 {
            mascotMood = .cheering
        } else if streakManager.todayPoints > 0 {
            mascotMood = .happy
        } else {
            mascotMood = .idle
        }
    }
    
    private func startAnimations() {
        // Bounce
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            bounce = true
        }
        
        // Wave arms
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.3)) {
            waveArm = true
        }
        
        // Show speech bubble with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showSpeechBubble = true
            }
        }
        
        // Eye blink every few seconds
        startBlinking()
        
        // Subtle body rotation
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            bodyRotation = 3
        }
    }
    
    private func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 2.5...4.5), repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                eyeBlink = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    eyeBlink = false
                }
            }
        }
    }
}

// MARK: - Mini Mascot for Header
struct MiniMascot: View {
    @State private var bounce = false
    let level: Int
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Design.Colors.primary, Design.Colors.primaryLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 36, height: 36)
            
            // Eyes
            HStack(spacing: 7) {
                Circle().fill(.white).frame(width: 6, height: 6)
                Circle().fill(.white).frame(width: 6, height: 6)
            }
            .offset(y: -3)
            
            // Smile
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(to: CGPoint(x: 10, y: 0), control: CGPoint(x: 5, y: 5))
            }
            .stroke(Color.white, lineWidth: 1.5)
            .frame(width: 10, height: 6)
            .offset(y: 5)
            
            // Crown for high level
            if level >= 10 {
                Image(systemName: "crown.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.yellow)
                    .offset(y: -19)
            }
        }
        .offset(y: bounce ? -2 : 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                bounce = true
            }
        }
    }
}
