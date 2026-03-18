import SwiftUI

// MARK: - ML Dashboard View
/// Shows the health and growth of GoFit's self-learning food recognition system.
/// Lets users see how their scans are making the AI smarter — gamifying the data collection!
struct MLDashboardView: View {
    @StateObject private var analyzer = HybridMealAnalyzer.shared
    @State private var dataStats: MealDataCollector.DatasetStats?
    @State private var isExporting = false
    @State private var exportResult: MealTrainingExporter.ExportResult?
    @State private var showExportSheet = false
    @State private var showClearConfirm = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: Design.Spacing.lg) {
                headerSection
                
                if let stats = dataStats {
                    performanceCard(stats)
                    datasetGrowthCard(stats)
                    
                    if !stats.topFoods.isEmpty {
                        topFoodsCard(stats)
                    }
                    
                    trainingReadinessCard(stats)
                    actionsCard(stats)
                } else {
                    emptyStateCard
                }
            }
            .padding()
        }
        .background(Design.Colors.background.ignoresSafeArea())
        .navigationTitle("AI Brain")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { refreshStats() }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Clear All Training Data?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                MealDataCollector.shared.clearAllData()
                HybridMealAnalyzer.shared.resetStats()
                refreshStats()
                HapticManager.shared.warning()
            }
        } message: {
            Text("This will delete all collected food images and labels. The AI will have to relearn everything from scratch.")
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: Design.Spacing.xs) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Design.Colors.primary, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Your AI is Learning")
                .font(Design.Typography.title2)
                .foregroundColor(.primary)
            
            Text("Every meal scan makes the AI smarter.\nSoon it won't need the cloud at all!")
                .font(Design.Typography.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
    
    // MARK: - Performance Card
    
    private func performanceCard(_ stats: MealDataCollector.DatasetStats) -> some View {
        VStack(spacing: Design.Spacing.md) {
            HStack {
                Image(systemName: "gauge.with.dots.needle.67percent")
                    .foregroundColor(Design.Colors.primary)
                Text("AI Performance")
                    .font(Design.Typography.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            let analyzerStats = analyzer.analyzerStats
            
            HStack(spacing: Design.Spacing.md) {
                statBubble(
                    value: "\(analyzerStats.totalScans)",
                    label: "Total Scans",
                    icon: "camera",
                    color: .blue
                )
                
                statBubble(
                    value: "\(analyzerStats.localScans)",
                    label: "On-Device",
                    icon: "iphone",
                    color: .green
                )
                
                statBubble(
                    value: "\(analyzerStats.apiScans)",
                    label: "Cloud AI",
                    icon: "cloud",
                    color: .orange
                )
                
                statBubble(
                    value: "$\(String(format: "%.2f", analyzerStats.apiSavings))",
                    label: "Saved",
                    icon: "dollarsign.circle",
                    color: .mint
                )
            }
            
            // Local hit rate progress
            VStack(spacing: 4) {
                HStack {
                    Text("On-Device Success Rate")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.0f", analyzer.localHitRate))%")
                        .font(Design.Typography.caption.bold())
                        .foregroundColor(hitRateColor)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.15))
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [hitRateColor.opacity(0.8), hitRateColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(analyzer.localHitRate / 100))
                    }
                }
                .frame(height: 10)
            }
        }
        .padding()
        .background(Design.Colors.cardBackground)
        .cornerRadius(Design.Radius.large)
    }
    
    // MARK: - Dataset Growth Card
    
    private func datasetGrowthCard(_ stats: MealDataCollector.DatasetStats) -> some View {
        VStack(spacing: Design.Spacing.md) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.purple)
                Text("Dataset Growth")
                    .font(Design.Typography.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack(spacing: Design.Spacing.md) {
                statBubble(
                    value: "\(stats.totalSamples)",
                    label: "Samples",
                    icon: "photo.stack",
                    color: .purple
                )
                
                statBubble(
                    value: "\(stats.uniqueFoods)",
                    label: "Foods Known",
                    icon: "fork.knife",
                    color: .pink
                )
                
                statBubble(
                    value: "\(stats.userEditedSamples)",
                    label: "User Verified",
                    icon: "checkmark.seal",
                    color: .green
                )
                
                statBubble(
                    value: String(format: "%.1f MB", stats.diskUsageMB),
                    label: "Storage",
                    icon: "internaldrive",
                    color: .gray
                )
            }
        }
        .padding()
        .background(Design.Colors.cardBackground)
        .cornerRadius(Design.Radius.large)
    }
    
    // MARK: - Top Foods Card
    
    private func topFoodsCard(_ stats: MealDataCollector.DatasetStats) -> some View {
        VStack(spacing: Design.Spacing.sm) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.orange)
                Text("Most Learned Foods")
                    .font(Design.Typography.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            let maxCount = stats.topFoods.first?.value ?? 1
            
            ForEach(stats.topFoods.prefix(8), id: \.key) { food in
                HStack(spacing: Design.Spacing.sm) {
                    Text(food.key.capitalized)
                        .font(Design.Typography.caption)
                        .foregroundColor(.primary)
                        .frame(width: 100, alignment: .leading)
                        .lineLimit(1)
                    
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Design.Colors.primary.opacity(0.6), Design.Colors.primary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(food.value) / CGFloat(maxCount))
                    }
                    .frame(height: 16)
                    
                    Text("\(food.value)")
                        .font(Design.Typography.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                        .frame(width: 30, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Design.Colors.cardBackground)
        .cornerRadius(Design.Radius.large)
    }
    
    // MARK: - Training Readiness Card
    
    private func trainingReadinessCard(_ stats: MealDataCollector.DatasetStats) -> some View {
        VStack(spacing: Design.Spacing.md) {
            HStack {
                Image(systemName: stats.isReadyForTraining ? "checkmark.circle.fill" : "hourglass")
                    .foregroundColor(stats.isReadyForTraining ? .green : .orange)
                Text("Training Readiness")
                    .font(Design.Typography.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            if stats.isReadyForTraining {
                Label {
                    Text("Your dataset is ready to train a custom food AI model!")
                        .font(Design.Typography.caption)
                        .foregroundColor(.green)
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundColor(.green)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    readinessRow(
                        label: "Food samples",
                        current: stats.totalSamples,
                        required: 50,
                        met: stats.totalSamples >= 50
                    )
                    readinessRow(
                        label: "Unique foods",
                        current: stats.uniqueFoods,
                        required: 10,
                        met: stats.uniqueFoods >= 10
                    )
                }
            }
            
            // Milestone progress
            let milestones: [(Int, String)] = [
                (50, "Basic Recognition"),
                (200, "Good Accuracy"),
                (500, "Great Accuracy"),
                (1000, "Expert Level"),
                (5000, "Master AI")
            ]
            
            let currentMilestone = milestones.last { $0.0 <= stats.totalSamples } ?? milestones[0]
            let nextMilestone = milestones.first { $0.0 > stats.totalSamples } ?? milestones.last!
            
            VStack(spacing: 4) {
                HStack {
                    Text("Level: \(currentMilestone.1)")
                        .font(Design.Typography.caption.bold())
                        .foregroundColor(Design.Colors.primary)
                    Spacer()
                    Text("Next: \(nextMilestone.0) samples")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
                
                let progress = min(1.0, Double(stats.totalSamples) / Double(nextMilestone.0))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.15))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [.purple, Design.Colors.primary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 10)
            }
        }
        .padding()
        .background(Design.Colors.cardBackground)
        .cornerRadius(Design.Radius.large)
    }
    
    // MARK: - Actions Card
    
    private func actionsCard(_ stats: MealDataCollector.DatasetStats) -> some View {
        VStack(spacing: Design.Spacing.sm) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundColor(.secondary)
                Text("Tools")
                    .font(Design.Typography.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            // Export training data
            Button {
                exportTrainingData()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(isExporting ? "Exporting..." : "Export Training Data")
                    Spacer()
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                }
                .font(Design.Typography.body)
                .foregroundColor(.primary)
                .padding()
                .background(Design.Colors.primary.opacity(0.1))
                .cornerRadius(Design.Radius.medium)
            }
            .disabled(isExporting || stats.totalSamples == 0)
            
            // Prune old data
            Button {
                MealDataCollector.shared.pruneOldSamples(olderThanDays: 90)
                HapticManager.shared.lightTap()
                refreshStats()
            } label: {
                HStack {
                    Image(systemName: "scissors")
                    Text("Prune Data Older Than 90 Days")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .font(Design.Typography.body)
                .foregroundColor(.primary)
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(Design.Radius.medium)
            }
            
            // Clear all data
            Button {
                showClearConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Training Data")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .font(Design.Typography.body)
                .foregroundColor(.red)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(Design.Radius.medium)
            }
        }
        .padding()
        .background(Design.Colors.cardBackground)
        .cornerRadius(Design.Radius.large)
    }
    
    // MARK: - Empty State
    
    private var emptyStateCard: some View {
        VStack(spacing: Design.Spacing.md) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))
            
            Text("No Training Data Yet")
                .font(Design.Typography.headline)
                .foregroundColor(.primary)
            
            Text("Start scanning meals! Every scan teaches the AI to recognize foods on its own, so it won't need the cloud.")
                .font(Design.Typography.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Design.Spacing.xl)
        .background(Design.Colors.cardBackground)
        .cornerRadius(Design.Radius.large)
    }
    
    // MARK: - Helper Views
    
    private func statBubble(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(Design.Typography.caption.bold().monospacedDigit())
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func readinessRow(label: String, current: Int, required: Int, met: Bool) -> some View {
        HStack {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundColor(met ? .green : .gray)
                .font(.system(size: 14))
            Text("\(label): \(current)/\(required)")
                .font(Design.Typography.caption)
                .foregroundColor(met ? .green : .secondary)
            Spacer()
        }
    }
    
    private var hitRateColor: Color {
        switch analyzer.localHitRate {
        case 0..<20: return .red
        case 20..<50: return .orange
        case 50..<80: return .green
        default: return Design.Colors.primary
        }
    }
    
    // MARK: - Actions
    
    private func refreshStats() {
        dataStats = MealDataCollector.shared.stats
    }
    
    private func exportTrainingData() {
        isExporting = true
        HapticManager.shared.lightTap()
        
        Task {
            do {
                let url = try await MealTrainingExporter.shared.createShareableArchive()
                await MainActor.run {
                    shareURL = url
                    showShareSheet = true
                    isExporting = false
                    HapticManager.shared.success()
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    HapticManager.shared.error()
                }
                #if DEBUG
                print("❌ Export failed: \(error)")
                #endif
            }
        }
    }
}

#Preview {
    NavigationStack {
        MLDashboardView()
    }
}
