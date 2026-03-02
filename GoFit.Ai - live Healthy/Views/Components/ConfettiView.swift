//
//  ConfettiView.swift
//  GoFit.Ai - live Healthy
//
//  Celebration confetti effect for achievements and milestones
//

import SwiftUI

struct ConfettiView: View {
    @State private var confetti: [ConfettiPiece] = []
    @State private var isAnimating = false
    
    let colors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink,
        Design.Colors.primary, Design.Colors.accent
    ]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(confetti) { piece in
                    ConfettiPieceView(piece: piece)
                }
            }
        }
        .onAppear {
            createConfetti()
        }
        .allowsHitTesting(false)
    }
    
    private func createConfetti() {
        let screenWidth = UIScreen.main.bounds.width
        
        for i in 0..<100 {
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 0...screenWidth),
                y: -50,
                color: colors.randomElement() ?? .yellow,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.2),
                delay: Double(i) * 0.02,
                shape: ConfettiShape.allCases.randomElement() ?? .circle
            )
            confetti.append(piece)
        }
    }
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    @State private var yOffset: CGFloat = 0
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        Group {
            switch piece.shape {
            case .circle:
                Circle()
                    .fill(piece.color)
                    .frame(width: 10 * piece.scale, height: 10 * piece.scale)
            case .rectangle:
                Rectangle()
                    .fill(piece.color)
                    .frame(width: 12 * piece.scale, height: 8 * piece.scale)
            case .star:
                Image(systemName: "star.fill")
                    .font(.system(size: 12 * piece.scale))
                    .foregroundColor(piece.color)
            case .triangle:
                Triangle()
                    .fill(piece.color)
                    .frame(width: 10 * piece.scale, height: 10 * piece.scale)
            }
        }
        .rotationEffect(.degrees(rotation))
        .position(x: piece.x + xOffset, y: piece.y + yOffset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 3).delay(piece.delay)) {
                yOffset = UIScreen.main.bounds.height + 100
                xOffset = CGFloat.random(in: -100...100)
                rotation = piece.rotation + Double.random(in: 360...720)
            }
            
            withAnimation(.easeIn(duration: 1).delay(piece.delay + 2)) {
                opacity = 0
            }
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let color: Color
    let rotation: Double
    let scale: CGFloat
    let delay: Double
    let shape: ConfettiShape
}

enum ConfettiShape: CaseIterable {
    case circle
    case rectangle
    case star
    case triangle
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

// MARK: - Celebration Overlay
struct CelebrationOverlay: View {
    @Binding var isShowing: Bool
    let message: String
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            if isShowing {
                // Background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissCelebration()
                    }
                
                // Confetti
                ConfettiView()
                
                // Message card
                VStack(spacing: 20) {
                    Text("🎉")
                        .font(.system(size: 60))
                    
                    Text(message)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: dismissCelebration) {
                        Text("Awesome!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(Design.Colors.primaryGradient)
                            .cornerRadius(25)
                    }
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Design.Colors.cardBackground)
                        .shadow(color: .black.opacity(0.3), radius: 20)
                )
                .scaleEffect(scale)
                .opacity(opacity)
                .onAppear {
                    HapticManager.shared.success()
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        scale = 1.0
                        opacity = 1.0
                    }
                }
            }
        }
    }
    
    private func dismissCelebration() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 0.8
            opacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isShowing = false
        }
    }
}

// MARK: - View Extension
extension View {
    func celebration(isShowing: Binding<Bool>, message: String) -> some View {
        ZStack {
            self
            CelebrationOverlay(isShowing: isShowing, message: message)
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        ConfettiView()
    }
}
