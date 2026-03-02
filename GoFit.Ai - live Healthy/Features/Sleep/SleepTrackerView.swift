//
//  SleepTrackerView.swift
//  GoFit.Ai - live Healthy
//
//  Sleep tracking interface
//

import SwiftUI

struct SleepTrackerView: View {
    @StateObject private var sleepManager = SleepManager.shared
    @State private var showingLogSheet = false
    @State private var showingHistory = false
    @State private var showingSettings = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Design.Spacing.lg) {
                    // Sleep Score Card
                    sleepScoreCard
                        .delayedAppear(0)
                    
                    // Last Night Summary
                    if let today = sleepManager.todayEntry {
                        lastNightCard(entry: today)
                            .delayedAppear(0.1)
                    } else {
                        noSleepLoggedCard
                            .delayedAppear(0.1)
                    }
                    
                    // Weekly Trend
                    weeklyTrendCard
                        .delayedAppear(0.2)
                    
                    // Sleep Goal Progress
                    sleepGoalCard
                        .delayedAppear(0.3)
                    
                    // Sleep Tip
                    sleepTipCard
                        .delayedAppear(0.4)
                }
                .padding(.horizontal, Design.Spacing.md)
                .padding(.bottom, Design.Spacing.xl)
            }
            .background(Design.Colors.background.ignoresSafeArea())
            .navigationTitle("Sleep Tracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            HapticManager.shared.lightTap()
                            showingHistory = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(Design.Colors.primary)
                        }
                        
                        Button {
                            HapticManager.shared.lightTap()
                            showingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(Design.Colors.primary)
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                logSleepButton
                    .padding(.bottom, Design.Spacing.lg)
            }
            .sheet(isPresented: $showingLogSheet) {
                LogSleepSheet()
            }
            .sheet(isPresented: $showingHistory) {
                SleepHistoryView()
            }
            .sheet(isPresented: $showingSettings) {
                SleepSettingsView()
            }
        }
    }
    
    // MARK: - Sleep Score Card
    private var sleepScoreCard: some View {
        VStack(spacing: Design.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sleep Score")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(sleepManager.weeklyStats?.sleepScore ?? 0)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor)
                        
                        Text("/ 100")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: Double(sleepManager.weeklyStats?.sleepScore ?? 0) / 100)
                        .stroke(
                            LinearGradient(
                                colors: [Design.Colors.primary, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: "moon.stars.fill")
                        .font(.title)
                        .foregroundColor(Design.Colors.primary)
                }
            }
            
            // Quality indicators
            HStack(spacing: Design.Spacing.lg) {
                StatItem(
                    icon: "bed.double.fill",
                    value: sleepManager.weeklyStats?.averageDurationFormatted ?? "—",
                    label: "Avg Duration"
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    icon: "star.fill",
                    value: String(format: "%.1f", sleepManager.weeklyStats?.averageQuality ?? 0),
                    label: "Avg Quality"
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    icon: "calendar",
                    value: "\(sleepManager.weeklyStats?.totalEntries ?? 0)",
                    label: "This Week"
                )
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.primary.opacity(0.08), radius: 15, x: 0, y: 5)
    }
    
    private var scoreColor: Color {
        let score = sleepManager.weeklyStats?.sleepScore ?? 0
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }
    
    // MARK: - Last Night Card
    private func lastNightCard(entry: SleepEntry) -> some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            HStack {
                Text("Last Night")
                    .font(.headline)
                
                Spacer()
                
                Text(entry.quality.emoji + " " + entry.quality.label)
                    .font(.subheadline)
                    .foregroundColor(entry.quality.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(entry.quality.color.opacity(0.15))
                    .cornerRadius(20)
            }
            
            HStack(spacing: Design.Spacing.xl) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Bedtime", systemImage: "moon.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.bedtime.formatted(date: .omitted, time: .shortened))
                        .font(.title2.weight(.semibold))
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("Wake Up", systemImage: "sun.max.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.wakeTime.formatted(date: .omitted, time: .shortened))
                        .font(.title2.weight(.semibold))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.durationFormatted)
                        .font(.title2.weight(.bold))
                        .foregroundColor(Design.Colors.primary)
                }
            }
            
            if let mood = entry.mood {
                HStack {
                    Text("Morning mood:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(mood.emoji + " " + mood.label)
                        .font(.caption.weight(.medium))
                }
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
    
    // MARK: - No Sleep Logged Card
    private var noSleepLoggedCard: some View {
        VStack(spacing: Design.Spacing.md) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 50))
                .foregroundColor(Design.Colors.primary.opacity(0.5))
            
            Text("No sleep logged yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Tap the button below to log last night's sleep")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Design.Spacing.xl)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
    
    // MARK: - Weekly Trend Card
    private var weeklyTrendCard: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Text("Weekly Trend")
                .font(.headline)
            
            if let stats = sleepManager.weeklyStats, !stats.weeklyTrend.isEmpty {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(stats.weeklyTrend) { day in
                        VStack(spacing: 4) {
                            // Bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(day.duration > 0 ? Design.Colors.primaryGradient : Color.gray.opacity(0.2))
                                .frame(width: 30, height: max(CGFloat(day.duration / sleepManager.sleepGoal) * 80, 10))
                            
                            // Day label
                            Text(day.dayOfWeek)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120)
                
                // Goal line indicator
                HStack {
                    Text("Goal: \(Int(sleepManager.sleepGoal))h")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let best = stats.bestNight {
                        Text("Best: \(best.durationFormatted)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            } else {
                Text("Log more sleep to see trends")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Design.Spacing.lg)
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
    
    // MARK: - Sleep Goal Card
    private var sleepGoalCard: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            HStack {
                Text("Sleep Goal")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(sleepManager.sleepGoal)) hours")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Design.Colors.primary, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * sleepManager.goalProgress)
                }
            }
            .frame(height: 12)
            
            HStack {
                if let today = sleepManager.todayEntry {
                    Text("\(today.durationFormatted) logged")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("No sleep logged today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\(Int(sleepManager.goalProgress * 100))% of goal")
                    .font(.caption.weight(.medium))
                    .foregroundColor(Design.Colors.primary)
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
    }
    
    // MARK: - Sleep Tip Card
    private var sleepTipCard: some View {
        HStack(spacing: Design.Spacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(.title2)
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep Tip")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(sleepManager.randomTip)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
        .padding(Design.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.yellow.opacity(0.1))
        )
    }
    
    // MARK: - Log Sleep Button
    private var logSleepButton: some View {
        Button {
            HapticManager.shared.mediumTap()
            showingLogSheet = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Log Sleep")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Design.Colors.primaryGradient)
            .cornerRadius(30)
            .shadow(color: Design.Colors.primary.opacity(0.4), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Design.Colors.primary)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Log Sleep Sheet
struct LogSleepSheet: View {
    @ObservedObject private var sleepManager = SleepManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var bedtime = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var quality: SleepQuality = .good
    @State private var mood: SleepMood = .neutral
    @State private var notes = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Sleep Time") {
                    DatePicker("Bedtime", selection: $bedtime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Wake Time", selection: $wakeTime, displayedComponents: [.date, .hourAndMinute])
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(durationFormatted)
                            .foregroundColor(Design.Colors.primary)
                            .fontWeight(.semibold)
                    }
                }
                
                Section("Sleep Quality") {
                    HStack(spacing: 12) {
                        ForEach(SleepQuality.allCases, id: \.self) { q in
                            Button {
                                HapticManager.shared.lightTap()
                                quality = q
                            } label: {
                                VStack(spacing: 4) {
                                    Text(q.emoji)
                                        .font(.title2)
                                    Text(q.label)
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(quality == q ? q.color.opacity(0.2) : Color.clear)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(quality == q ? q.color : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section("Morning Mood") {
                    HStack(spacing: 8) {
                        ForEach(SleepMood.allCases, id: \.self) { m in
                            Button {
                                HapticManager.shared.lightTap()
                                mood = m
                            } label: {
                                VStack(spacing: 2) {
                                    Text(m.emoji)
                                        .font(.title3)
                                    Text(m.label)
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(mood == m ? Design.Colors.primary.opacity(0.15) : Color.clear)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Log Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        HapticManager.shared.success()
                        sleepManager.logSleep(
                            bedtime: bedtime,
                            wakeTime: wakeTime,
                            quality: quality,
                            notes: notes.isEmpty ? nil : notes,
                            mood: mood
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var durationFormatted: String {
        let duration = wakeTime.timeIntervalSince(bedtime)
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Sleep History View
struct SleepHistoryView: View {
    @ObservedObject private var sleepManager = SleepManager.shared
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sleepManager.sleepEntries) { entry in
                    SleepHistoryRow(entry: entry)
                }
                .onDelete(perform: deleteEntries)
            }
            .navigationTitle("Sleep History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            sleepManager.deleteEntry(sleepManager.sleepEntries[index])
        }
    }
}

struct SleepHistoryRow: View {
    let entry: SleepEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                
                Spacer()
                
                Text(entry.quality.emoji)
                Text(entry.durationFormatted)
                    .font(.subheadline)
                    .foregroundColor(Design.Colors.primary)
                    .fontWeight(.semibold)
            }
            
            HStack {
                Label(entry.bedtime.formatted(date: .omitted, time: .shortened), systemImage: "moon.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Label(entry.wakeTime.formatted(date: .omitted, time: .shortened), systemImage: "sun.max.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Sleep Settings View
struct SleepSettingsView: View {
    @ObservedObject private var sleepManager = SleepManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var sleepGoal: Double = 8.0
    @State private var reminderEnabled = false
    @State private var reminderTime = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Sleep Goal") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(Int(sleepGoal)) hours")
                            .font(.title2.weight(.bold))
                            .foregroundColor(Design.Colors.primary)
                        
                        Slider(value: $sleepGoal, in: 4...12, step: 0.5) {
                            Text("Sleep Goal")
                        }
                        
                        Text("Recommended: 7-9 hours for adults")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Bedtime Reminder") {
                    Toggle("Enable Reminder", isOn: $reminderEnabled)
                    
                    if reminderEnabled {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
                
                Section("HealthKit") {
                    Button {
                        Task {
                            try? await sleepManager.requestHealthKitAuthorization()
                        }
                    } label: {
                        Label("Sync with Apple Health", systemImage: "heart.fill")
                    }
                }
            }
            .navigationTitle("Sleep Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        sleepManager.setSleepGoal(sleepGoal)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                sleepGoal = sleepManager.sleepGoal
            }
        }
    }
}

#Preview {
    SleepTrackerView()
}
