
import SwiftUI
import Foundation

// Import local models and services for Analytics

// NOTE: Ensure AnalyticsData.swift and NetworkManager+Analytics.swift are in the same target as this file.
// If you see 'Cannot find type' errors, add these files to the build target in Xcode.

struct AnalyticsDashboardView: View {
    @State private var analytics: AnalyticsData?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var period: String = "weekly"
    @ObservedObject private var retentionManager = RetentionManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Text("Analytics & Progress")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)

                    retentionOverviewSection
                    
                    if isLoading {
                        ProgressView("Loading analytics...")
                            .padding()
                    } else if let analytics = analytics {
                        // Calories Chart
                        if let calories = analytics.nutrition.averageCalories {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Avg Calories (") + Text(period.capitalized) + Text(")")
                                    .font(.headline)
                                ChartView(data: [calories], labels: [period.capitalized], color: .orange, valueLabel: "kcal")
                            }
                            .padding()
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(16)
                        }
                        // Steps Chart (if available)
                        if let fitness = analytics.fitness.totalWorkouts {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Workouts (") + Text(period.capitalized) + Text(")")
                                    .font(.headline)
                                ChartView(data: [Double(fitness)], labels: [period.capitalized], color: .green, valueLabel: "workouts")
                            }
                            .padding()
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(16)
                        }
                        // AI Insights
                        if let insights = analytics.insights, !insights.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("AI Insights")
                                    .font(.headline)
                                ForEach(insights, id: \.self) { insight in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.blue)
                                        Text(insight)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.12))
                            .cornerRadius(16)
                        }
                    } else if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .task {
                await loadAnalytics()
            }
        }
    }
    
    private func loadAnalytics() async {
        isLoading = true
        errorMessage = nil
        do {
            let data = try await NetworkManager.shared.fetchAnalytics(period: period)
            analytics = data
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private var retentionOverviewSection: some View {
        let insights = retentionManager.insights

        return VStack(alignment: .leading, spacing: 16) {
            Text("Retention Overview")
                .font(.title3)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                retentionMetricCard(title: "D1 Activation", value: insights.activatedWithinOneDay ? "Yes" : "No", subtitle: insights.isActivated ? "First meaningful action recorded" : "Not activated yet", color: .blue)
                retentionMetricCard(title: "7-Day Active", value: "\(insights.activeDaysLast7)/7", subtitle: "Weekly consistency \(insights.weeklyConsistencyScore)%", color: .green)
            }

            HStack(spacing: 12) {
                retentionMetricCard(title: "30-Day Active", value: "\(insights.activeDaysLast30)/30", subtitle: "Habit depth", color: .orange)
                retentionMetricCard(title: "Comebacks", value: "\(insights.comebackCount)", subtitle: "Successful reactivations", color: .purple)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Milestones")
                    .font(.headline)

                ForEach(insights.milestoneStatus) { milestone in
                    HStack(spacing: 10) {
                        Image(systemName: milestone.isReached ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(milestone.isReached ? .green : .secondary)
                        Text(milestone.title)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }

            HStack {
                Label("Best open hour: \(formattedHour(insights.bestOpenHour))", systemImage: "clock.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Label("Installed \(insights.daysSinceInstall)d ago", systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.12))
        .cornerRadius(16)
    }

    private func retentionMetricCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white.opacity(0.7))
        .cornerRadius(14)
    }

    private func formattedHour(_ hour: Int) -> String {
        let normalizedHour = max(0, min(23, hour))
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(hour: normalizedHour)) ?? Date()
        return formatter.string(from: date)
    }
}

struct ChartView: View {
    let data: [Double]
    let labels: [String]
    let color: Color
    let valueLabel: String
    
    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(data.indices, id: \.self) { i in
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color)
                                .frame(height: CGFloat(data[i]) / (data.max() ?? 1) * (geo.size.height - 24))
                        }
                    }
                }
                .frame(height: geo.size.height - 20)
                HStack(spacing: 8) {
                    ForEach(labels, id: \.self) { label in
                        Text(label)
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(height: 120)
    }
}

#Preview {
    AnalyticsDashboardView()
}
