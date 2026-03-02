//
//  EnhancedAnimations.swift
//  GoFit.Ai - live Healthy
//
//  Enhanced animations and micro-interactions
//

import SwiftUI

// MARK: - Shimmer Loading Effect
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let isActive: Bool
    
    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .clear,
                                .white.opacity(0.4),
                                .clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 2)
                        .offset(x: -geo.size.width + (geo.size.width * 2 * phase))
                    }
                )
                .mask(content)
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        phase = 1
                    }
                }
        } else {
            content
        }
    }
}

extension View {
    func shimmer(isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - Skeleton Loading View
struct SkeletonView: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    
    init(width: CGFloat? = nil, height: CGFloat = 20, cornerRadius: CGFloat = 8) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Pulse Animation
struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing && isActive ? 1.05 : 1.0)
            .opacity(isPulsing && isActive ? 0.8 : 1.0)
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulse(isActive: Bool = true) -> some View {
        modifier(PulseModifier(isActive: isActive))
    }
}

// MARK: - Bounce Animation
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.interpolatingSpring(stiffness: 400, damping: 10), value: configuration.isPressed)
    }
}

// MARK: - Glow Effect
struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let isActive: Bool
    @State private var isGlowing = false
    
    func body(content: Content) -> some View {
        content
            .shadow(
                color: isActive ? color.opacity(isGlowing ? 0.8 : 0.3) : .clear,
                radius: isActive ? (isGlowing ? radius * 1.5 : radius) : 0
            )
            .onAppear {
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isGlowing = true
                }
            }
    }
}

extension View {
    func glow(color: Color = .blue, radius: CGFloat = 10, isActive: Bool = true) -> some View {
        modifier(GlowModifier(color: color, radius: radius, isActive: isActive))
    }
}

// MARK: - Floating Animation
struct FloatingModifier: ViewModifier {
    @State private var offset: CGFloat = 0
    let amount: CGFloat
    let duration: Double
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    offset = amount
                }
            }
    }
}

extension View {
    func floating(amount: CGFloat = 5, duration: Double = 2) -> some View {
        modifier(FloatingModifier(amount: amount, duration: duration))
    }
}

// MARK: - Shake Animation
struct ShakeModifier: ViewModifier {
    @Binding var isShaking: Bool
    let intensity: CGFloat
    
    func body(content: Content) -> some View {
        content
            .offset(x: isShaking ? intensity : 0)
            .animation(
                isShaking ?
                    Animation.linear(duration: 0.05).repeatCount(6, autoreverses: true) :
                    .default,
                value: isShaking
            )
            .onChange(of: isShaking) { _, newValue in
                if newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isShaking = false
                    }
                }
            }
    }
}

extension View {
    func shake(isShaking: Binding<Bool>, intensity: CGFloat = 10) -> some View {
        modifier(ShakeModifier(isShaking: isShaking, intensity: intensity))
    }
}

// MARK: - Typing Animation Text
struct TypeWriterText: View {
    let text: String
    let speed: Double
    @State private var displayedText = ""
    @State private var currentIndex = 0
    
    var body: some View {
        Text(displayedText)
            .onAppear {
                startTyping()
            }
    }
    
    private func startTyping() {
        displayedText = ""
        currentIndex = 0
        
        Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { timer in
            if currentIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: currentIndex)
                displayedText += String(text[index])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Counting Number Animation
struct CountingNumberView: View {
    let value: Double
    let format: String
    let duration: Double
    
    @State private var displayValue: Double = 0
    
    var body: some View {
        Text(String(format: format, displayValue))
            .onAppear {
                withAnimation(.easeOut(duration: duration)) {
                    displayValue = value
                }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.easeOut(duration: duration * 0.5)) {
                    displayValue = newValue
                }
            }
    }
}

// MARK: - Progress Ring
struct AnimatedProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradient: LinearGradient
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Design.Animation.smooth, value: animatedProgress)
        }
        .onAppear {
            animatedProgress = min(progress, 1.0)
        }
        .onChange(of: progress) { _, newValue in
            animatedProgress = min(newValue, 1.0)
        }
    }
}

// MARK: - Card Flip Animation
struct FlipView<Front: View, Back: View>: View {
    @Binding var isFlipped: Bool
    let front: Front
    let back: Back
    
    var body: some View {
        ZStack {
            front
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)
            
            back
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isFlipped)
    }
}

// MARK: - Success Checkmark Animation
struct SuccessCheckmark: View {
    @State private var drawCheckmark = false
    @State private var circleScale: CGFloat = 0
    
    let size: CGFloat
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: size, height: size)
                .scaleEffect(circleScale)
            
            Path { path in
                let width = size * 0.6
                let height = size * 0.6
                let startX = (size - width) / 2 + width * 0.2
                let startY = (size - height) / 2 + height * 0.5
                
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: startX + width * 0.25, y: startY + height * 0.25))
                path.addLine(to: CGPoint(x: startX + width * 0.6, y: startY - height * 0.3))
            }
            .trim(from: 0, to: drawCheckmark ? 1 : 0)
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                circleScale = 1
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                drawCheckmark = true
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        SkeletonView(width: 200, height: 20)
        
        AnimatedProgressRing(
            progress: 0.7,
            lineWidth: 8,
            gradient: Design.Colors.primaryGradient
        )
        .frame(width: 100, height: 100)
        
        SuccessCheckmark(size: 60, color: .green)
    }
    .padding()
}
