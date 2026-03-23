import SwiftUI
import UIKit

// MARK: - Human Body Liquid Visualization
/// Shows a human body silhouette that fills with color based on drinks logged
struct HumanBodyLiquidView: View {
    let entries: [LiquidEntry]
    let goal: Double
    
    @State private var fillLevel: CGFloat = 0
    @State private var wavePhase: CGFloat = 0
    
    private var totalIntake: Double {
        entries.reduce(0) { $0 + $1.amount }
    }
    
    private var progress: CGFloat {
        guard goal > 0 else { return 0 }
        return min(CGFloat(totalIntake / goal), 1.0)
    }
    
    // Compute dominant color from beverage mix
    private var liquidColor: Color {
        guard !entries.isEmpty else { return .blue.opacity(0.4) }
        
        // Weight each beverage's color by its volume
        let total = totalIntake
        guard total > 0 else { return .blue.opacity(0.4) }
        
        var r: Double = 0, g: Double = 0, b: Double = 0
        
        for entry in entries {
            let weight = entry.amount / total
            let c = beverageColor(entry.beverageType)
            let resolved = UIColor(c)
            var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
            resolved.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
            r += Double(cr) * weight
            g += Double(cg) * weight
            b += Double(cb) * weight
        }
        
        return Color(red: r, green: g, blue: b)
    }
    
    // Color segments for the visual breakdown strip
    private var beverageSegments: [(type: LiquidEntry.BeverageType, ratio: CGFloat, color: Color)] {
        guard totalIntake > 0 else { return [] }
        
        var segments: [(type: LiquidEntry.BeverageType, amount: Double)] = []
        for entry in entries {
            if let idx = segments.firstIndex(where: { $0.type == entry.beverageType }) {
                segments[idx].amount += entry.amount
            } else {
                segments.append((type: entry.beverageType, amount: entry.amount))
            }
        }
        
        return segments.map { seg in
            (type: seg.type, ratio: CGFloat(seg.amount / totalIntake), color: beverageColor(seg.type))
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Body silhouette with fill
            ZStack {
                // Background body outline
                BodySilhouette()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 120, height: 220)
                
                // Liquid fill inside body
                BodySilhouette()
                    .fill(Color.gray.opacity(0.05))
                    .frame(width: 120, height: 220)
                
                // Animated fill
                BodySilhouette()
                    .fill(liquidColor.opacity(0.7))
                    .frame(width: 120, height: 220)
                    .mask(
                        VStack {
                            Spacer()
                            Rectangle()
                                .frame(height: 220 * fillLevel)
                        }
                        .frame(width: 120, height: 220)
                    )
                    .overlay(
                        // Wave effect at water line
                        BodySilhouette()
                            .fill(liquidColor.opacity(0.3))
                            .frame(width: 120, height: 220)
                            .mask(
                                WaveShape(phase: wavePhase, amplitude: 3)
                                    .frame(width: 120, height: 220)
                                    .offset(y: 110 - (220 * fillLevel) + 110)
                            )
                    )
                
                // Percentage label
                VStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(.title2, design: .rounded).bold())
                        .foregroundColor(progress > 0.4 ? .white : .primary)
                    
                    Text(String(format: "%.1fL", totalIntake))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(progress > 0.4 ? .white.opacity(0.9) : .secondary)
                }
            }
            .frame(height: 220)
            
            // Beverage breakdown strip
            if !beverageSegments.isEmpty {
                VStack(spacing: 8) {
                    // Segmented bar
                    GeometryReader { geo in
                        HStack(spacing: 1) {
                            ForEach(Array(beverageSegments.enumerated()), id: \.offset) { _, seg in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(seg.color)
                                    .frame(width: max(geo.size.width * seg.ratio - 1, 4))
                            }
                        }
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                    
                    // Legend
                    HStack(spacing: 12) {
                        ForEach(Array(beverageSegments.enumerated()), id: \.offset) { _, seg in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(seg.color)
                                    .frame(width: 8, height: 8)
                                Text(seg.type.displayName)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                fillLevel = progress
            }
            // Continuous wave animation
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
        .onChange(of: entries.count) { _ in
            withAnimation(.easeOut(duration: 0.8)) {
                fillLevel = progress
            }
        }
    }
    
    private func beverageColor(_ type: LiquidEntry.BeverageType) -> Color {
        switch type {
        case .water: return Color(red: 0.2, green: 0.7, blue: 1.0)           // Sky blue
        case .coffee: return Color(red: 0.55, green: 0.35, blue: 0.17)       // Brown
        case .tea: return Color(red: 0.6, green: 0.8, blue: 0.3)             // Green tea
        case .juice: return Color(red: 1.0, green: 0.7, blue: 0.2)           // Orange
        case .soda, .softDrink: return Color(red: 0.65, green: 0.16, blue: 0.16)  // Cola red
        case .beer: return Color(red: 0.95, green: 0.75, blue: 0.15)         // Amber
        case .wine: return Color(red: 0.5, green: 0.0, blue: 0.13)           // Wine red
        case .liquor: return Color(red: 0.8, green: 0.65, blue: 0.2)         // Whiskey amber
        case .alcohol: return Color(red: 0.8, green: 0.65, blue: 0.2)
        case .other: return Color.gray
        }
    }
}

// MARK: - Body Silhouette Shape
struct BodySilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Head
        let headCenterX = w * 0.5
        let headCenterY = h * 0.08
        let headRadius = w * 0.12
        path.addEllipse(in: CGRect(
            x: headCenterX - headRadius,
            y: headCenterY - headRadius,
            width: headRadius * 2,
            height: headRadius * 2.2
        ))
        
        // Neck
        path.move(to: CGPoint(x: w * 0.44, y: h * 0.13))
        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.13))
        
        // Torso + body
        path.move(to: CGPoint(x: w * 0.44, y: h * 0.15))
        // Left shoulder
        path.addCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.22),
            control1: CGPoint(x: w * 0.35, y: h * 0.16),
            control2: CGPoint(x: w * 0.2, y: h * 0.18)
        )
        // Left arm
        path.addCurve(
            to: CGPoint(x: w * 0.1, y: h * 0.45),
            control1: CGPoint(x: w * 0.12, y: h * 0.30),
            control2: CGPoint(x: w * 0.1, y: h * 0.38)
        )
        // Left hand
        path.addCurve(
            to: CGPoint(x: w * 0.18, y: h * 0.45),
            control1: CGPoint(x: w * 0.08, y: h * 0.47),
            control2: CGPoint(x: w * 0.12, y: h * 0.47)
        )
        // Left side torso
        path.addCurve(
            to: CGPoint(x: w * 0.22, y: h * 0.55),
            control1: CGPoint(x: w * 0.22, y: h * 0.40),
            control2: CGPoint(x: w * 0.20, y: h * 0.50)
        )
        // Left hip
        path.addCurve(
            to: CGPoint(x: w * 0.25, y: h * 0.62),
            control1: CGPoint(x: w * 0.22, y: h * 0.58),
            control2: CGPoint(x: w * 0.23, y: h * 0.60)
        )
        // Left leg
        path.addCurve(
            to: CGPoint(x: w * 0.28, y: h * 0.92),
            control1: CGPoint(x: w * 0.26, y: h * 0.72),
            control2: CGPoint(x: w * 0.27, y: h * 0.85)
        )
        // Left foot
        path.addCurve(
            to: CGPoint(x: w * 0.38, y: h * 0.95),
            control1: CGPoint(x: w * 0.26, y: h * 0.95),
            control2: CGPoint(x: w * 0.32, y: h * 0.96)
        )
        // Inner left leg
        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.62))
        
        // Center
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.60))
        
        // Inner right leg
        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.62))
        
        // Right foot
        path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.95))
        path.addCurve(
            to: CGPoint(x: w * 0.72, y: h * 0.92),
            control1: CGPoint(x: w * 0.68, y: h * 0.96),
            control2: CGPoint(x: w * 0.74, y: h * 0.95)
        )
        // Right leg
        path.addCurve(
            to: CGPoint(x: w * 0.75, y: h * 0.62),
            control1: CGPoint(x: w * 0.73, y: h * 0.85),
            control2: CGPoint(x: w * 0.74, y: h * 0.72)
        )
        // Right hip
        path.addCurve(
            to: CGPoint(x: w * 0.78, y: h * 0.55),
            control1: CGPoint(x: w * 0.77, y: h * 0.60),
            control2: CGPoint(x: w * 0.78, y: h * 0.58)
        )
        // Right side torso
        path.addCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.45),
            control1: CGPoint(x: w * 0.80, y: h * 0.50),
            control2: CGPoint(x: w * 0.78, y: h * 0.40)
        )
        // Right hand
        path.addCurve(
            to: CGPoint(x: w * 0.9, y: h * 0.45),
            control1: CGPoint(x: w * 0.88, y: h * 0.47),
            control2: CGPoint(x: w * 0.92, y: h * 0.47)
        )
        // Right arm
        path.addCurve(
            to: CGPoint(x: w * 0.85, y: h * 0.22),
            control1: CGPoint(x: w * 0.9, y: h * 0.38),
            control2: CGPoint(x: w * 0.88, y: h * 0.30)
        )
        // Right shoulder
        path.addCurve(
            to: CGPoint(x: w * 0.56, y: h * 0.15),
            control1: CGPoint(x: w * 0.8, y: h * 0.18),
            control2: CGPoint(x: w * 0.65, y: h * 0.16)
        )
        
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Wave Shape
struct WaveShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let midY = rect.midY
        
        path.move(to: CGPoint(x: 0, y: midY))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let y = midY + sin((relativeX * .pi * 2 * 2) + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Beverage Selector Button
struct BeverageSelectorButton: View {
    let type: String
    let name: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected ? color : color.opacity(0.1))
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? .white : color)
                }
                
                Text(name)
                    .font(.system(size: 10, design: .rounded))
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? color : .secondary)
            }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
