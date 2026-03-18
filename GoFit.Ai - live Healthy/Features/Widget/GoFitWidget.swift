import SwiftUI
import WidgetKit

// MARK: - Widget Timeline Provider
struct GoFitTimelineProvider: TimelineProvider {
    
    func placeholder(in context: Context) -> GoFitWidgetEntry {
        GoFitWidgetEntry.placeholder
    }
    
    func getSnapshot(in context: Context, completion: @escaping (GoFitWidgetEntry) -> Void) {
        completion(currentEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<GoFitWidgetEntry>) -> Void) {
        let entry = currentEntry()
        // Refresh every 15 minutes
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(next))
        completion(timeline)
    }
    
    private func currentEntry() -> GoFitWidgetEntry {
        let store = GoFitWidgetDataStore.shared
        return GoFitWidgetEntry(
            date: Date(),
            waterLiters: store.waterLiters,
            waterGoal: store.waterGoal,
            calories: store.calories,
            protein: store.protein,
            mealCount: store.mealCount,
            steps: store.steps
        )
    }
}

// MARK: - Widget Entry
struct GoFitWidgetEntry: TimelineEntry {
    let date: Date
    let waterLiters: Double
    let waterGoal: Double
    let calories: Double
    let protein: Double
    let mealCount: Int
    let steps: Int
    
    var waterProgress: Double { min(waterLiters / max(waterGoal, 0.1), 1.0) }
    
    static let placeholder = GoFitWidgetEntry(
        date: Date(),
        waterLiters: 1.2,
        waterGoal: 2.0,
        calories: 1450,
        protein: 85,
        mealCount: 3,
        steps: 6800
    )
}

// MARK: - Widget Definition
struct GoFitWidget: Widget {
    let kind = "GoFitWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GoFitTimelineProvider()) { entry in
            GoFitWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    Color.black
                }
        }
        .configurationDisplayName("GoFit Dashboard")
        .description("Track water, calories, and progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget Bundle (register multiple widgets if needed)
struct GoFitWidgetBundle: WidgetBundle {
    var body: some Widget {
        GoFitWidget()
    }
}

// MARK: - Small Widget View
struct GoFitWidgetSmallView: View {
    let entry: GoFitWidgetEntry
    
    private let brandGreen = Color(red: 0.2, green: 0.85, blue: 0.4)
    private let brandBlue = Color(red: 0.3, green: 0.6, blue: 1.0)
    
    var body: some View {
        VStack(spacing: 8) {
            // Water Ring
            ZStack {
                Circle()
                    .stroke(brandGreen.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: entry.waterProgress)
                    .stroke(
                        AngularGradient(
                            colors: [brandBlue, brandGreen, brandGreen],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 0) {
                    Text("💧")
                        .font(.system(size: 16))
                    Text(String(format: "%.1fL", entry.waterLiters))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 70, height: 70)
            
            // Calories
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                Text("\(Int(entry.calories))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("cal")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            
            // Meals
            HStack(spacing: 4) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 10))
                    .foregroundColor(brandGreen)
                Text("\(entry.mealCount) meals")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
    }
}

// MARK: - Medium Widget View
struct GoFitWidgetMediumView: View {
    let entry: GoFitWidgetEntry
    
    private let brandGreen = Color(red: 0.2, green: 0.85, blue: 0.4)
    private let brandBlue = Color(red: 0.3, green: 0.6, blue: 1.0)
    
    var body: some View {
        HStack(spacing: 16) {
            // Left: Water Ring
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(brandGreen.opacity(0.2), lineWidth: 10)
                    
                    Circle()
                        .trim(from: 0, to: entry.waterProgress)
                        .stroke(
                            AngularGradient(
                                colors: [brandBlue, brandGreen, brandGreen],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 1) {
                        Text("💧")
                            .font(.system(size: 18))
                        Text(String(format: "%.1fL", entry.waterLiters))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("/ \(String(format: "%.1fL", entry.waterGoal))")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 85, height: 85)
                
                Text(entry.waterProgress >= 1.0 ? "Goal Met! 🎉" : "\(Int(entry.waterProgress * 100))%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(entry.waterProgress >= 1.0 ? brandGreen : .gray)
            }
            
            // Right: Stats Grid
            VStack(alignment: .leading, spacing: 10) {
                // App Name
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(brandGreen)
                        .font(.system(size: 10))
                    Text("GoFit")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Stats
                statRow(icon: "flame.fill", color: .orange, label: "Calories", value: "\(Int(entry.calories))")
                statRow(icon: "figure.strengthtraining.traditional", color: brandGreen, label: "Protein", value: "\(Int(entry.protein))g")
                statRow(icon: "fork.knife", color: brandBlue, label: "Meals", value: "\(entry.mealCount)")
                
                if entry.steps > 0 {
                    statRow(icon: "figure.walk", color: .yellow, label: "Steps", value: "\(entry.steps)")
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
    }
    
    @ViewBuilder
    private func statRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Entry View Router
struct GoFitWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: GoFitWidgetEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            GoFitWidgetSmallView(entry: entry)
        case .systemMedium:
            GoFitWidgetMediumView(entry: entry)
        default:
            GoFitWidgetMediumView(entry: entry)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct GoFitWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GoFitWidgetSmallView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .containerBackground(for: .widget) { Color.black }
            
            GoFitWidgetMediumView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .containerBackground(for: .widget) { Color.black }
        }
    }
}
#endif
