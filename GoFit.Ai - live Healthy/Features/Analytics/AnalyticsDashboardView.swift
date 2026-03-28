
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Text("Analytics & Progress")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
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
