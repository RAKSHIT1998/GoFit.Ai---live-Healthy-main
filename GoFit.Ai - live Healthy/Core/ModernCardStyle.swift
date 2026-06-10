import SwiftUI

// MARK: - Modern Card Component

struct ModernCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Design.Spacing.lg
    var backgroundColor: Color?
    var cornerRadius: CGFloat = Design.Radius.large
    var useGlass: Bool = false
    var showShimmerBorder: Bool = true

    @Environment(\.colorScheme) var colorScheme

    init(
        padding: CGFloat = Design.Spacing.lg,
        backgroundColor: Color? = nil,
        cornerRadius: CGFloat = Design.Radius.large,
        useGlass: Bool = false,
        showShimmerBorder: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.useGlass = useGlass
        self.showShimmerBorder = showShimmerBorder
        self.content = content()
    }

    private var resolvedBackground: Color {
        if let bg = backgroundColor { return bg }
        return Design.Colors.cardBackground
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    // Base fill — glass or solid
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(useGlass
                            ? resolvedBackground.opacity(0.45)
                            : resolvedBackground)

                    if useGlass {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                    }

                    // Top-left shimmer line (dark mode only)
                    if colorScheme == .dark && showShimmerBorder {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.10),
                                        Color.white.opacity(0.03),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                }
            )
            // Primary glow shadow
            .shadow(color: Design.Colors.primary.opacity(colorScheme == .dark ? 0.10 : 0.06),
                    radius: 14, x: 0, y: 5)
            // Depth shadow
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.04),
                    radius: 2, x: 0, y: 1)
    }
}

// MARK: - Gradient Primary Button

struct ModernButtonStyle: ButtonStyle {
    var useGradient: Bool = true
    var backgroundColor: Color = Design.Colors.primary
    var foregroundColor: Color = .white
    var height: CGFloat = Design.Scale.value(52, textStyle: .body)
    var cornerRadius: CGFloat = Design.Radius.medium

    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Design.Typography.headline)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                Group {
                    if useGradient {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Design.Colors.primaryGradient)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(backgroundColor)
                    }
                }
            )
            .overlay(
                // Inner top highlight
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            .shadow(color: Design.Colors.primary.opacity(configuration.isPressed ? 0.15 : 0.28),
                    radius: configuration.isPressed ? 4 : 10, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(Design.Animation.springFast, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
            }
    }
}

// MARK: - Secondary Outlined Button

struct ModernSecondaryButtonStyle: ButtonStyle {
    var borderColor: Color = Design.Colors.primary
    var foregroundColor: Color = Design.Colors.primary
    var height: CGFloat = Design.Scale.value(52, textStyle: .body)
    var cornerRadius: CGFloat = Design.Radius.medium

    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Design.Typography.headline)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(colorScheme == .dark
                        ? Color.white.opacity(0.05)
                        : Design.Colors.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [borderColor.opacity(0.9), borderColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(Design.Animation.springFast, value: configuration.isPressed)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil
    var accentColor: Color = Design.Colors.primary

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Design.Typography.title3)
                .foregroundStyle(.primary)

            Spacer()

            if let action, let actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(Design.Typography.subheadline)
                        .foregroundStyle(accentColor)
                }
            }
        }
        .padding(.horizontal, Design.Spacing.md)
        .padding(.vertical, Design.Spacing.xs)
    }
}

// MARK: - Stat Badge (compact metric chip)

struct StatBadge: View {
    let value: String
    let label: String
    var color: Color = Design.Colors.primary

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Design.Typography.numberSmall)
                .foregroundStyle(color)
            Text(label)
                .font(Design.Typography.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Design.Spacing.sm)
        .padding(.vertical, Design.Spacing.xs)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.small))
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil
    var iconColor: Color = Design.Colors.primary

    var body: some View {
        VStack(spacing: Design.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.10))
                    .frame(width: 88, height: 88)

                Image(systemName: icon)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(iconColor.opacity(0.7))
            }

            VStack(spacing: Design.Spacing.xs) {
                Text(title)
                    .font(Design.Typography.title2)
                    .foregroundStyle(.primary)

                Text(message)
                    .font(Design.Typography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Design.Spacing.xl)
            }

            if let action, let actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(ModernButtonStyle())
                .padding(.horizontal, Design.Spacing.xl)
                .padding(.top, Design.Spacing.sm)
            }
        }
        .padding(.vertical, Design.Spacing.xl)
    }
}
