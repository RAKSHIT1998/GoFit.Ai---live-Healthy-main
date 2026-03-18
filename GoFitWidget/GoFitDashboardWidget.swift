import SwiftUI
import WidgetKit

// MARK: - Shared Data Reader
/// Reads data from App Group UserDefaults written by the main app.
struct WidgetDataReader {
    static let appGroupID = "group.com.rakshit.gofitai"
    private static let prefix = "widget_"
    
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }
    
    static var waterLiters: Double { defaults.double(forKey: k("waterLiters")) }
    static var waterGoal: Double {
        let g = defaults.double(forKey: k("waterGoal"))
        return g > 0 ? g : 2.0
    }
    static var waterProgress: Double { min(waterLiters / max(waterGoal, 0.1), 1.0) }
    static var mealCount: Int { defaults.integer(forKey: k("mealCount")) }
    static var calories: Double { defaults.double(forKey: k("calories")) }
    static var protein: Double { defaults.double(forKey: k("protein")) }
    static var steps: Int { defaults.integer(forKey: k("steps")) }
    
    private static func k(_ key: String) -> String { "\(prefix)\(key)" }
}

// MARK: - Timeline Entry
struct GoFitEntry: TimelineEntry {
    let date: Date
    let waterLiters: Double
    let waterGoal: Double
    let calories: Double
    let protein: Double
    let mealCount: Int
    let steps: Int
    
    var waterProgress: Double { min(waterLiters / max(waterGoal, 0.1), 1.0) }
    
    static let placeholder = GoFitEntry(
        date: Date(), waterLiters: 1.2, waterGoal: 2.0,
        calories: 1450, protein: 85, mealCount: 3, steps: 6800
    )
}

// MARK: - Timeline Provider
struct GoFitTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> GoFitEntry { .placeholder }
    
    func getSnapshot(in context: Context, completion: @escaping (GoFitEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<GoFitEntry>) -> Void) {
        let entry = currentEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
    
    private func currentEntry() -> GoFitEntry {
        GoFitEntry(
            date: Date(),
            waterLiters: WidgetDataReader.waterLiters,
            waterGoal: WidgetDataReader.waterGoal,
            calories: WidgetDataReader.calories,
            protein: WidgetDataReader.protein,
            mealCount: WidgetDataReader.mealCount,
            steps: WidgetDataReader.steps
        )
    }
}

// MARK: - Widget Definition
struct GoFitDashboardWidget: Widget {
    let kind = "GoFitWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GoFitTimelineProvider()) { entry in
            GoFitWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.05, blue: 0.1), Color(red: 0.08, green: 0.08, blue: 0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("GoFit Dashboard")
        .description("Track water, calories, and progress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Entry View Router
struct GoFitWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: GoFitEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            GoFitSmallView(entry: entry)
        case .systemMedium:
            GoFitMediumView(entry: entry)
        default:
            GoFitMediumView(entry: entry)
        }
    }
}

// MARK: - Brand Colors
private let brandGreen = Color(red: 0.2, green: 0.85, blue: 0.4)
private let brandBlue = Color(red: 0.3, green: 0.6, blue: 1.0)
private let brandOrange = Color(red: 1.0, green: 0.6, blue: 0.2)

// MARK: - Small Widget View
struct GoFitSmallView: View {
    let entry: GoFitEntry
    
    var body: some View {
        VStack(spacing: 6) {
            // Water Ring
            ZStack {
                Circle()
                    .stroke(brandGreen.opacity(0.15), lineWidth: 8)
                
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
                        .font(.system(size: 14))
                    Text(String(format: "%.1fL", entry.waterLiters))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 68, height: 68)
            
            // Calories
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 9))
                    .foregroundColor(brandOrange)
                Text("\(Int(entry.calories))")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("cal")
                    .font(.system(size: 9))
                    .foregroundColor(.gray)
            }
            
            // Meals
            HStack(spacing: 3) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 9))
                    .foregroundColor(brandGreen)
                Text("\(entry.mealCount) meals")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
        }
        .padding(6)
    }
}

// MARK: - Medium Widget View
struct GoFitMediumView: View {
    let entry: GoFitEntry
    
    var body: some View {
        HStack(spacing: 14) {
            // Left: Water Ring
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .stroke(brandGreen.opacity(0.15), lineWidth: 10)
                    
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
                            .font(.system(size: 16))
                        Text(String(format: "%.1fL", entry.waterLiters))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("/ \(String(format: "%.1fL", entry.waterGoal))")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 82, height: 82)
                
                Text(entry.waterProgress >= 1.0 ? "Goal Met! 🎉" : "\(Int(entry.waterProgress * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(entry.waterProgress >= 1.0 ? brandGreen : .gray)
            }
            
            // Right: Stats
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(brandGreen)
                        .font(.system(size: 10))
                    Text("GoFit")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                statRow(icon: "flame.fill", color: brandOrange, label: "Calories", value: "\(Int(entry.calories))")
                statRow(icon: "figure.strengthtraining.traditional", color: brandGreen, label: "Protein", value: "\(Int(entry.protein))g")
                statRow(icon: "fork.knife", color: brandBlue, label: "Meals", value: "\(entry.mealCount)")
                
                if entry.steps > 0 {
                    statRow(icon: "figure.walk", color: .yellow, label: "Steps", value: "\(entry.steps)")
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(10)
    }
    
    @ViewBuilder
    private func statRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(color)
                .frame(width: 14)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Previews
#if DEBUG
struct GoFitWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GoFitSmallView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .containerBackground(for: .widget) {
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                }
            
            GoFitMediumView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .containerBackground(for: .widget) {
                    Color(red: 0.05, green: 0.05, blue: 0.1)
                }
        }
    }
}
#endif
