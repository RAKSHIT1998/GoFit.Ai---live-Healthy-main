import SwiftUI

struct FirstTimeTutorialView: View {
    let onFinish: () -> Void

    @State private var currentPage = 0

    private let pages: [TutorialPage] = [
        TutorialPage(
            icon: "hand.tap.fill",
            title: "Welcome to GoFit.AI",
            subtitle: "Here’s a quick tour so you can use the app confidently from day one."
        ),
        TutorialPage(
            icon: "house.fill",
            title: "Home Tab",
            subtitle: "See your daily calories, macros, steps, streaks, and progress in one place."
        ),
        TutorialPage(
            icon: "camera.fill",
            title: "Log Meals Fast",
            subtitle: "Tap Scan Meal on Home to capture food with camera, or add meals manually."
        ),
        TutorialPage(
            icon: "fork.knife.circle.fill",
            title: "Meals Tab",
            subtitle: "Review your meal history and nutrition breakdowns for each day."
        ),
        TutorialPage(
            icon: "person.2.circle.fill",
            title: "Social Tab",
            subtitle: "Add friends, chat, and share your daily log progress."
        ),
        TutorialPage(
            icon: "person.circle.fill",
            title: "Profile Tab",
            subtitle: "Update personal details, goals, and app preferences anytime."
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Design.Colors.primary.opacity(0.12),
                    Design.Colors.background,
                    Design.Colors.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    Button("Skip") {
                        onFinish()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        tutorialPage(page)
                            .tag(index)
                            .padding(.horizontal, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                ProgressView(value: Double(currentPage + 1), total: Double(pages.count))
                    .progressViewStyle(.linear)
                    .tint(Design.Colors.primary)
                    .padding(.horizontal, 24)

                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentPage += 1
                        }
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(currentPage == pages.count - 1 ? "Start Using App" : "Next")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Design.Colors.primary)
                        .cornerRadius(14)
                }
                .buttonStyle(SmoothButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    @ViewBuilder
    private func tutorialPage(_ page: TutorialPage) -> some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 56, weight: .semibold))
                .foregroundColor(Design.Colors.primary)
                .padding(24)
                .background(Design.Colors.primary.opacity(0.1))
                .clipShape(Circle())

            Text(page.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)

            Spacer()
        }
    }
}

private struct TutorialPage {
    let icon: String
    let title: String
    let subtitle: String
}
