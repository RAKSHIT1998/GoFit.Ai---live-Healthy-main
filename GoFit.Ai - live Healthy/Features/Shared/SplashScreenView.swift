//
//  SplashScreenView.swift
//  GoFit.Ai - live Healthy
//
//  Beautiful animated splash screen for faster perceived loading
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isAnimating = false
    @State private var showPulse = false
    @State private var showTagline = false
    @State private var progress: CGFloat = 0
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Design.Colors.primary.opacity(0.9),
                    Design.Colors.primaryDark,
                    Color.black.opacity(0.2)
                ],
                startPoint: isAnimating ? .topLeading : .bottomTrailing,
                endPoint: isAnimating ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
            
            // Floating particles
            FloatingParticlesView()
            
            VStack(spacing: 30) {
                Spacer()
                
                // App icon with pulse effect
                ZStack {
                    // Pulse rings
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(Color.white.opacity(0.3 - Double(index) * 0.1), lineWidth: 2)
                            .frame(width: showPulse ? CGFloat(120 + index * 40) : 80, 
                                   height: showPulse ? CGFloat(120 + index * 40) : 80)
                            .scaleEffect(showPulse ? 1.2 : 0.8)
                            .opacity(showPulse ? 0 : 1)
                            .animation(
                                .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                                value: showPulse
                            )
                    }
                    
                    // Logo
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .white.opacity(0.5), radius: 20)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
                }
                
                // App name with animated reveal
                VStack(spacing: 8) {
                    Text("GoFit.Ai")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 10)
                    
                    if showTagline {
                        Text("Live Healthy • Be Happy")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .transition(.opacity.combined(with: .scale))
                    }
                }
                
                Spacer()
                
                // Loading progress bar
                VStack(spacing: 12) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 6)
                    .frame(maxWidth: 200)
                    
                    Text("Loading your fitness journey...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Start background animation immediately
        withAnimation {
            isAnimating = true
        }
        
        // Start pulse effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showPulse = true
        }
        
        // Show tagline
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showTagline = true
            }
        }
        
        // Animate progress bar
        simulateLoading()
    }
    
    private func simulateLoading() {
        // Fast initial progress (perceived speed)
        withAnimation(.easeOut(duration: 0.3)) {
            progress = 0.3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeInOut(duration: 0.4)) {
                progress = 0.6
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeInOut(duration: 0.3)) {
                progress = 0.85
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                progress = 1.0
            }
        }
        
        // Complete splash after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            onComplete()
        }
    }
}

// MARK: - Floating Particles
struct FloatingParticlesView: View {
    @State private var particles: [Particle] = []
    
    var body: some View {
        GeometryReader { geo in
            ForEach(particles) { particle in
                Circle()
                    .fill(Color.white.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .blur(radius: 1)
            }
        }
        .onAppear {
            createParticles()
            animateParticles()
        }
    }
    
    private func createParticles() {
        particles = (0..<20).map { _ in
            Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                    y: CGFloat.random(in: 0...UIScreen.main.bounds.height)
                ),
                size: CGFloat.random(in: 4...12),
                opacity: Double.random(in: 0.1...0.4)
            )
        }
    }
    
    private func animateParticles() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            for i in particles.indices {
                particles[i].position.y -= CGFloat.random(in: 0.5...2)
                particles[i].position.x += CGFloat.random(in: -0.5...0.5)
                
                if particles[i].position.y < -20 {
                    particles[i].position.y = UIScreen.main.bounds.height + 20
                    particles[i].position.x = CGFloat.random(in: 0...UIScreen.main.bounds.width)
                }
            }
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
}

#Preview {
    SplashScreenView(onComplete: {})
}
