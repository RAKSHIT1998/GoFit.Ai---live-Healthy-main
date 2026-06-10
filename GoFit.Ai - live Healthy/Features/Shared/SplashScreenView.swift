import SwiftUI

struct SplashScreenView: View {
    @State private var blobsAnimating = false
    @State private var logoScale: CGFloat = 0.6
    @State private var logoOpacity: CGFloat = 0
    @State private var textOpacity: CGFloat = 0
    @State private var textOffset: CGFloat = 12
    @State private var taglineOpacity: CGFloat = 0
    @State private var progress: CGFloat = 0

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // ── Aurora background ─────────────────────────────
            Color(red: 0.031, green: 0.043, blue: 0.078)
                .ignoresSafeArea()

            AuroraBackground(animating: blobsAnimating)

            // ── Content ───────────────────────────────────────
            VStack(spacing: 0) {
                Spacer()

                // Logo mark
                ZStack {
                    // Glow rings
                    ForEach(0..<2, id: \.self) { i in
                        Circle()
                            .stroke(
                                Design.Colors.primaryGradient,
                                lineWidth: 1
                            )
                            .frame(width: CGFloat(96 + i * 36),
                                   height: CGFloat(96 + i * 36))
                            .opacity(blobsAnimating ? 0 : Double(0.3 - Double(i) * 0.12))
                            .scaleEffect(blobsAnimating ? 1.4 : 0.9)
                            .animation(
                                .easeOut(duration: 2.0)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.55),
                                value: blobsAnimating
                            )
                    }

                    // App icon container
                    ZStack {
                        Circle()
                            .fill(Design.Colors.primaryGradient)
                            .frame(width: 80, height: 80)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.22), Color.clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .frame(width: 80, height: 80)

                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Design.Colors.primary.opacity(0.55), radius: 24, x: 0, y: 0)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                // App name
                VStack(spacing: 6) {
                    Text("GoFit.Ai")
                        .font(.system(size: 40, weight: .heavy, design: .default))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, Color(white: 0.88)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text(tagline)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .opacity(taglineOpacity)
                }
                .padding(.top, 24)
                .offset(y: textOffset)
                .opacity(textOpacity)

                Spacer()

                // Progress bar
                VStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.10))
                            Capsule()
                                .fill(Design.Colors.primaryGradient)
                                .frame(width: geo.size.width * progress)
                                .animation(.easeInOut(duration: 0.25), value: progress)
                        }
                    }
                    .frame(height: 3)
                    .frame(maxWidth: 180)

                    Text(loadingMessage)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
                .padding(.bottom, 52)
            }
        }
        .onAppear { launch() }
    }

    // MARK: - Computed content

    private var tagline: String {
        let lines = [
            "Live Healthy · Feel Electric",
            "AI-Powered Fitness Coach",
            "Eat Smart · Train Hard · Win Big",
            "Level Up Your Health Game",
        ]
        return lines[Calendar.current.component(.minute, from: Date()) % lines.count]
    }

    private var loadingMessage: String {
        let msgs = [
            "Warming up your gains...",
            "Charging your fitness energy...",
            "Feeding the AI brain...",
            "Calibrating awesomeness...",
            "Unlocking beast mode...",
        ]
        return msgs[Calendar.current.component(.second, from: Date()) % msgs.count]
    }

    // MARK: - Animation sequence

    private func launch() {
        blobsAnimating = true

        withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.1)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.30)) {
            textOpacity = 1.0
            textOffset = 0
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.55)) {
            taglineOpacity = 1.0
        }

        // Progress simulation
        withAnimation(.easeOut(duration: 0.28).delay(0.05)) { progress = 0.28 }
        withAnimation(.easeInOut(duration: 0.35).delay(0.35)) { progress = 0.62 }
        withAnimation(.easeInOut(duration: 0.28).delay(0.72)) { progress = 0.88 }
        withAnimation(.easeInOut(duration: 0.20).delay(1.02)) { progress = 1.00 }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) { onComplete() }
    }
}

// MARK: - Aurora blobs

private struct AuroraBackground: View {
    let animating: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Indigo blob — top left
                Ellipse()
                    .fill(Color(red: 0.310, green: 0.275, blue: 0.898).opacity(0.28))
                    .frame(width: geo.size.width * 0.85, height: geo.size.height * 0.55)
                    .offset(
                        x: animating ? -geo.size.width * 0.15 : -geo.size.width * 0.10,
                        y: animating ? -geo.size.height * 0.20 : -geo.size.height * 0.15
                    )
                    .blur(radius: 60)
                    .animation(.easeInOut(duration: 5).repeatForever(autoreverses: true), value: animating)

                // Violet blob — bottom right
                Ellipse()
                    .fill(Color(red: 0.486, green: 0.231, blue: 0.929).opacity(0.22))
                    .frame(width: geo.size.width * 0.75, height: geo.size.height * 0.50)
                    .offset(
                        x: animating ? geo.size.width * 0.18 : geo.size.width * 0.12,
                        y: animating ? geo.size.height * 0.22 : geo.size.height * 0.16
                    )
                    .blur(radius: 70)
                    .animation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true), value: animating)

                // Fuchsia accent — bottom left
                Ellipse()
                    .fill(Color(red: 0.839, green: 0.290, blue: 0.682).opacity(0.14))
                    .frame(width: geo.size.width * 0.55, height: geo.size.height * 0.35)
                    .offset(
                        x: animating ? -geo.size.width * 0.22 : -geo.size.width * 0.16,
                        y: animating ? geo.size.height * 0.30 : geo.size.height * 0.24
                    )
                    .blur(radius: 55)
                    .animation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true), value: animating)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Legacy alias (kept so FloatingParticlesView usages compile)
struct FloatingParticlesView: View {
    var body: some View { EmptyView() }
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
