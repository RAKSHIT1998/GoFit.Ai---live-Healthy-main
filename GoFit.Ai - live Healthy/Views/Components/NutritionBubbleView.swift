import SwiftUI
import UIKit

// MARK: - Nutrition Bubble View
/// Floating animated bubbles showing nutrition info over food
struct NutritionBubbleOverlay: View {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let sugar: Double
    
    @State private var showBubbles = false
    @State private var bubbleScales: [CGFloat] = [0, 0, 0, 0, 0]
    @State private var bubbleOffsets: [CGSize] = Array(repeating: .zero, count: 5)
    @State private var floatPhase: [Bool] = Array(repeating: false, count: 5)
    
    private let bubbleData: [(icon: String, label: String, color: Color)]  = [
        ("flame.fill", "kcal", Design.Colors.calories),
        ("figure.strengthtraining.traditional", "Protein", Design.Colors.protein),
        ("leaf.fill", "Carbs", Design.Colors.carbs),
        ("drop.fill", "Fat", Design.Colors.fat),
        ("sparkles", "Sugar", Design.Colors.sugar),
    ]
    
    private var values: [Double] { [calories, protein, carbs, fat, sugar] }
    
    private func formattedValue(_ val: Double, at index: Int) -> String {
        if index == 0 { return "\(Int(val))" } // kcal, no "g"
        return "\(Int(val))g"
    }
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            // Position bubbles scattered around the image
            let positions: [CGPoint] = [
                CGPoint(x: w * 0.5, y: h * 0.18),   // Calories - top center (hero)
                CGPoint(x: w * 0.18, y: h * 0.45),   // Protein - left
                CGPoint(x: w * 0.82, y: h * 0.40),   // Carbs - right
                CGPoint(x: w * 0.25, y: h * 0.75),   // Fat - bottom left
                CGPoint(x: w * 0.75, y: h * 0.72),   // Sugar - bottom right
            ]
            
            ForEach(0..<5, id: \.self) { i in
                let isHero = i == 0
                let size: CGFloat = isHero ? 80 : 60
                
                if values[i] > 0 {
                    VStack(spacing: 2) {
                        Image(systemName: bubbleData[i].icon)
                            .font(isHero ? .title3 : .caption)
                            .foregroundColor(.white)
                        
                        Text(formattedValue(values[i], at: i))
                            .font(isHero ? .system(.headline, design: .rounded).bold() : .system(.caption2, design: .rounded).bold())
                            .foregroundColor(.white)
                        
                        Text(bubbleData[i].label)
                            .font(.system(size: isHero ? 10 : 8, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(width: size, height: size)
                    .background(
                        Circle()
                            .fill(bubbleData[i].color.opacity(0.85))
                            .shadow(color: bubbleData[i].color.opacity(0.5), radius: 8, x: 0, y: 4)
                    )
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                    )
                    .scaleEffect(bubbleScales[i])
                    .offset(y: floatPhase[i] ? -4 : 4)
                    .position(positions[i])
                    .animation(
                        .easeInOut(duration: Double.random(in: 1.8...2.5))
                        .repeatForever(autoreverses: true),
                        value: floatPhase[i]
                    )
                }
            }
        }
        .onAppear {
            // Stagger bubble appearance
            for i in 0..<5 {
                let delay = Double(i) * 0.15 + 0.2
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        bubbleScales[i] = 1.0
                    }
                }
                // Start floating
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.5) {
                    floatPhase[i] = true
                }
            }
        }
    }
}

// MARK: - Scan Result Card with Bubbles
/// Replaces the plain result view with image + floating bubbles
struct ScanResultWithBubbles: View {
    let image: UIImage?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let sugar: Double
    let itemName: String
    
    @State private var imageScale: CGFloat = 0.95
    @State private var showShine = false
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Food image
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 280)
                        .clipped()
                        .cornerRadius(20)
                        .scaleEffect(imageScale)
                } else {
                    // Placeholder gradient
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 280)
                }
                
                // Gradient overlay for readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.3)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .cornerRadius(20)
                
                // Floating nutrition bubbles
                NutritionBubbleOverlay(
                    calories: calories,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                    sugar: sugar
                )
                
                // Item name at bottom
                VStack {
                    Spacer()
                    HStack {
                        Text(itemName)
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        Spacer()
                    }
                }
                
                // Shine effect
                if showShine {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.2), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .rotationEffect(.degrees(30))
                        .offset(x: showShine ? 300 : -300)
                        .animation(.easeInOut(duration: 0.8), value: showShine)
                }
            }
            .frame(height: 280)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                imageScale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showShine = true
            }
        }
    }
}

// MARK: - Celebration Burst
/// Particle burst effect when meal is logged
struct MealLogCelebration: View {
    @Binding var isShowing: Bool
    @State private var particles: [CelebrationParticle] = []
    
    struct CelebrationParticle: Identifiable {
        let id = UUID()
        var emoji: String
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var opacity: Double
        var rotation: Double
    }
    
    let emojis = ["🎉", "⭐", "✨", "🔥", "💪", "🎊", "🌟", "💯"]
    
    var body: some View {
        if isShowing {
            ZStack {
                ForEach(particles) { p in
                    Text(p.emoji)
                        .font(.system(size: 24))
                        .scaleEffect(p.scale)
                        .opacity(p.opacity)
                        .rotationEffect(.degrees(p.rotation))
                        .position(x: p.x, y: p.y)
                }
            }
            .allowsHitTesting(false)
            .onAppear {
                generateParticles()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isShowing = false
                }
            }
        }
    }
    
    private func generateParticles() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        for _ in 0..<20 {
            let startX = screenWidth / 2
            let startY = screenHeight / 2
            let particle = CelebrationParticle(
                emoji: emojis.randomElement()!,
                x: startX,
                y: startY,
                scale: 0.1,
                opacity: 1.0,
                rotation: 0
            )
            particles.append(particle)
            
            let endX = CGFloat.random(in: 20...(screenWidth - 20))
            let endY = CGFloat.random(in: 100...(screenHeight - 200))
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.5)) {
                if let idx = particles.firstIndex(where: { $0.id == particle.id }) {
                    particles[idx].x = endX
                    particles[idx].y = endY
                    particles[idx].scale = CGFloat.random(in: 0.8...1.5)
                    particles[idx].rotation = Double.random(in: -180...180)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.5)) {
                    if let idx = particles.firstIndex(where: { $0.id == particle.id }) {
                        particles[idx].opacity = 0
                        particles[idx].scale = 0.1
                    }
                }
            }
        }
    }
}
