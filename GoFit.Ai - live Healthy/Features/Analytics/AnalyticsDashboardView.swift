import SwiftUI

struct AnalyticsDashboardView: View {
    // Placeholder data for demonstration
    let caloriesData: [Double] = [2100, 1800, 2000, 2200, 1950, 2050, 2300]
    let stepsData: [Int] = [8000, 9500, 10000, 12000, 11000, 9000, 10500]
    let dates: [String] = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    let aiInsights: [String] = [
        "You hit your calorie goal 5/7 days!",
        "Try to increase your protein intake on workout days.",
        "Great job staying active! Steps above 10k for 4 days."
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    Text("Analytics & Progress")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    // Calories Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Calories (last 7 days)")
                            .font(.headline)
                        ChartView(data: caloriesData, labels: dates, color: .orange, valueLabel: "kcal")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(16)
                    
                    // Steps Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Steps (last 7 days)")
                            .font(.headline)
                        ChartView(data: stepsData.map { Double($0) }, labels: dates, color: .green, valueLabel: "steps")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(16)
                    
                    // AI Insights
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AI Insights")
                            .font(.headline)
                        ForEach(aiInsights, id: \.self) { insight in
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
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Analytics")
        }
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
