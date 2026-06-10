import SwiftUI
import UIKit

// MARK: - Design System 2025 — PULSE
// Electric Indigo/Violet replaces neon green.
// Dark-navy surfaces, teal & amber category colours, aurora gradients.
// Every property name stays identical so no call-sites need changing.

struct AppDesign {

    // ── Colors ────────────────────────────────────────────────
    struct Colors {

        // Primary — Electric Indigo (#4F46E5) → Violet (#7C3AED)
        static let primary      = Color(red: 0.310, green: 0.275, blue: 0.898) // #4F46E5
        static let primaryLight = Color(red: 0.506, green: 0.545, blue: 0.973) // #818CF8
        static let primaryDark  = Color(red: 0.486, green: 0.231, blue: 0.929) // #7C3AED
        static let accent       = Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B Amber

        // ── Adaptive Backgrounds ─────────────────────────────
        static var background: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 0.031, green: 0.043, blue: 0.078, alpha: 1) // #080B14 Deep navy-black
                    : UIColor(red: 0.945, green: 0.953, blue: 0.965, alpha: 1) // #F1F5F9 Slate-100
            })
        }
        static var cardBackground: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 0.059, green: 0.086, blue: 0.149, alpha: 1) // #0F1626 Dark navy
                    : UIColor.white
            })
        }
        static var secondaryBackground: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 0.094, green: 0.125, blue: 0.208, alpha: 1) // #182035 Elevated navy
                    : UIColor(red: 0.973, green: 0.980, blue: 0.992, alpha: 1) // #F8FAFC Slate-50
            })
        }
        static var borderColor: Color {
            Color(uiColor: UIColor { t in
                t.userInterfaceStyle == .dark
                    ? UIColor(red: 0.145, green: 0.176, blue: 0.259, alpha: 1) // #252D42 Subtle border
                    : UIColor(red: 0.886, green: 0.906, blue: 0.941, alpha: 1) // #E2E8F0 Slate-200
            })
        }

        // ── Gradients ─────────────────────────────────────────
        static var primaryGradient: LinearGradient {
            LinearGradient(
                colors: [primary, primaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        /// Aurora hero gradient — used on splash, paywall, etc.
        static var heroGradient: LinearGradient {
            LinearGradient(
                colors: [
                    Color(red: 0.310, green: 0.275, blue: 0.898), // Indigo
                    Color(red: 0.486, green: 0.231, blue: 0.929), // Violet
                    Color(red: 0.839, green: 0.290, blue: 0.682)  // Fuchsia tint
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        /// Subtle card-top shimmer for dark mode
        static var cardShimmer: LinearGradient {
            LinearGradient(
                colors: [Color.white.opacity(0.07), Color.white.opacity(0.01)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        // ── Glassmorphism ──────────────────────────────────────
        static func glassBackground(colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.75)
        }
        static var glassBackgroundDark: Color { Color.white.opacity(0.06) }

        // ── Category / Semantic Colors ─────────────────────────
        // Changed to a richer, more modern palette
        static let calories = Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444 Red-500
        static let protein  = Color(red: 0.231, green: 0.510, blue: 0.965) // #3B82F6 Blue-500
        static let carbs    = Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B Amber-500
        static let fat      = Color(red: 0.976, green: 0.451, blue: 0.086) // #F97316 Orange-500
        static let sugar    = Color(red: 0.925, green: 0.282, blue: 0.600) // #EC4899 Pink-500
        static let water    = Color(red: 0.024, green: 0.714, blue: 0.831) // #06B6D4 Cyan-500
        static let steps    = Color(red: 0.063, green: 0.725, blue: 0.506) // #10B981 Emerald-500
        static let heart    = Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444 Red-500
        static let success  = Color(red: 0.063, green: 0.725, blue: 0.506) // #10B981 Emerald-500
        static let warning  = Color(red: 0.961, green: 0.620, blue: 0.043) // #F59E0B Amber-500
        static let error    = Color(red: 0.937, green: 0.267, blue: 0.267) // #EF4444 Red-500
        static var secondary: Color { Color(uiColor: .secondaryLabel) }
    }

    // ── Typography ────────────────────────────────────────────
    // Display/title uses default (SF Pro) for a sharper, more premium weight.
    // Body text keeps rounded for a friendly, accessible feel.
    struct Typography {
        static let display     = Font.system(.largeTitle, design: .default).weight(.heavy)
        static let largeTitle  = Font.system(.largeTitle, design: .default).weight(.bold)
        static let title       = Font.system(.title,      design: .default).weight(.bold)
        static let title2      = Font.system(.title2,     design: .default).weight(.semibold)
        static let title3      = Font.system(.title3,     design: .default).weight(.semibold)

        // Body keeps .rounded for warmth
        static let headline    = Font.system(.headline,    design: .rounded).weight(.semibold)
        static let body        = Font.system(.body,        design: .rounded)
        static let bodyBold    = Font.system(.body,        design: .rounded).weight(.semibold)
        static let callout     = Font.system(.callout,     design: .rounded)
        static let subheadline = Font.system(.subheadline, design: .rounded).weight(.medium)
        static let footnote    = Font.system(.footnote,    design: .rounded)
        static let caption     = Font.system(.caption,     design: .rounded)
        static let caption2    = Font.system(.caption2,    design: .rounded)

        /// Numeric displays — monospaced-ish to avoid layout shift
        static let numberLarge  = Font.system(.largeTitle, design: .rounded).weight(.black)
        static let numberMedium = Font.system(.title2,     design: .rounded).weight(.bold)
        static let numberSmall  = Font.system(.title3,     design: .rounded).weight(.semibold)
    }

    // ── Adaptive Scale ────────────────────────────────────────
    struct Scale {
        static func value(_ base: CGFloat, textStyle: UIFont.TextStyle = .body) -> CGFloat {
            UIFontMetrics(forTextStyle: textStyle).scaledValue(for: base)
        }
    }

    // ── Spacing ───────────────────────────────────────────────
    struct Spacing {
        static var xs: CGFloat { Scale.value(4)  }
        static var sm: CGFloat { Scale.value(8)  }
        static var md: CGFloat { Scale.value(16) }
        static var lg: CGFloat { Scale.value(24) }
        static var xl: CGFloat { Scale.value(32) }
    }

    // ── Corner Radius ─────────────────────────────────────────
    struct Radius {
        static var small:  CGFloat { Scale.value(10) }   // was 8  — slightly rounder
        static var medium: CGFloat { Scale.value(14) }   // was 12
        static var large:  CGFloat { Scale.value(20) }   // was 16 — more pronounced
        static var xlarge: CGFloat { Scale.value(28) }   // was 24
    }

    // ── Shadows ───────────────────────────────────────────────
    // Two-layer shadow: a coloured mid-distance glow + a tight dark edge.
    struct Shadows {
        static var small: Shadow {
            Shadow(color: AppDesign.Colors.primary.opacity(0.08), radius: 6,  x: 0, y: 2)
        }
        static var medium: Shadow {
            Shadow(color: AppDesign.Colors.primary.opacity(0.12), radius: 14, x: 0, y: 5)
        }
        static var large: Shadow {
            Shadow(color: AppDesign.Colors.primary.opacity(0.18), radius: 24, x: 0, y: 10)
        }
        static var glow: Shadow {
            Shadow(color: AppDesign.Colors.primary.opacity(0.35), radius: 20, x: 0, y: 0)
        }
    }

    // ── Animation ─────────────────────────────────────────────
    struct Animation {
        static let spring     = SwiftUI.Animation.spring(response: 0.38, dampingFraction: 0.76)
        static let springFast = SwiftUI.Animation.spring(response: 0.22, dampingFraction: 0.72)
        static let springSlow = SwiftUI.Animation.spring(response: 0.55, dampingFraction: 0.82)
        static let easeInOut  = SwiftUI.Animation.easeInOut(duration: 0.28)
        static let smooth     = SwiftUI.Animation.spring(response: 0.32, dampingFraction: 0.82)
        static let bouncy     = SwiftUI.Animation.spring(response: 0.48, dampingFraction: 0.58)
    }
}

// ── Shadow value type ─────────────────────────────────────────
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// ── Global typealias ──────────────────────────────────────────
typealias Design = AppDesign

// MARK: - Card Style with Glass-Panel look

struct CardStyle: ViewModifier {
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let shadow: Shadow
    let useGlass: Bool

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(useGlass ? backgroundColor.opacity(0.5) : backgroundColor)
                    .background(
                        // Frosted blur for glass
                        Group {
                            if useGlass {
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(.ultraThinMaterial)
                            }
                        }
                    )
                    .overlay(
                        // Subtle top-left shimmer edge on dark mode
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.08 : 0.4),
                                        Color.white.opacity(0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
            // second tighter shadow for depth
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.04),
                    radius: 2, x: 0, y: 1)
    }
}

extension View {
    func cardStyle(
        backgroundColor: Color = Design.Colors.cardBackground,
        cornerRadius: CGFloat = AppDesign.Radius.large,
        shadow: Shadow = AppDesign.Shadows.medium,
        useGlass: Bool = false
    ) -> some View {
        modifier(CardStyle(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            shadow: shadow,
            useGlass: useGlass
        ))
    }
}

// MARK: - Animated Button Style with Haptic

struct AnimatedButtonStyle: ButtonStyle {
    let color: Color
    let isPrimary: Bool

    init(color: Color = AppDesign.Colors.primary, isPrimary: Bool = true) {
        self.color = color
        self.isPrimary = isPrimary
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(AppDesign.Animation.springFast, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

// MARK: - Pulse Animation (now uses primary glow colour)

struct PulseModifier: ViewModifier {
    @State private var isPulsing = false
    let color: Color

    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .fill(color.opacity(0.25))
                    .scaleEffect(isPulsing ? 1.6 : 1.0)
                    .opacity(isPulsing ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )
            .onAppear { isPulsing = true }
    }
}

extension View {
    func pulse(color: Color = AppDesign.Colors.primary) -> some View {
        modifier(PulseModifier(color: color))
    }
}

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -300
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.25),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false),
                           value: phase)
            )
            .onAppear { phase = 300 }
    }
}

extension View {
    func shimmer() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Glow modifier (new — for active elements)

struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius / 2, x: 0, y: 0)
            .shadow(color: color.opacity(0.25), radius: radius, x: 0, y: 0)
    }
}

extension View {
    func glow(color: Color = AppDesign.Colors.primary, radius: CGFloat = 12) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Gradient Text (new — for hero numbers)

extension View {
    func gradientForeground(colors: [Color], startPoint: UnitPoint = .leading, endPoint: UnitPoint = .trailing) -> some View {
        self.overlay(
            LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
        )
        .mask(self)
    }
}
