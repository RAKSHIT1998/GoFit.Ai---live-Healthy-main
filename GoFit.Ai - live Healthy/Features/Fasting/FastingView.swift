import SwiftUI

struct FastingView: View {
    @ObservedObject private var model = FastingTimerModel.shared
    @Environment(\.dismiss) var dismiss
    @State private var animateTimer = false

    var body: some View {
        NavigationView {
            ZStack {
                Design.Colors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Design.Spacing.xl) {
                        timerCircle
                            .padding(.top, Design.Spacing.lg)
                            .delayedAppear(0)
                        
                        statusCard
                            .padding(.horizontal, Design.Spacing.md)
                            .delayedAppear(0.1)
                        
                        if !model.isFasting {
                            presetWindowsSection
                                .padding(.horizontal, Design.Spacing.md)
                                .delayedAppear(0.2)
                        }
                        
                        streakCard
                            .padding(.horizontal, Design.Spacing.md)
                            .delayedAppear(0.3)
                        
                        if !model.fastingHistory.isEmpty {
                            historyCard
                                .padding(.horizontal, Design.Spacing.md)
                                .delayedAppear(0.35)
                        }
                        
                        actionButton
                            .padding(.horizontal, Design.Spacing.md)
                            .padding(.bottom, Design.Spacing.xl)
                            .delayedAppear(0.4)
                    }
                }
            }
            .navigationTitle("Intermittent Fasting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        HapticManager.shared.lightTap()
                        dismiss()
                    }
                    .foregroundColor(Design.Colors.primary)
                    .font(Design.Typography.body)
                }
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                model.updateTimer()
            }
            .onAppear {
                withAnimation(Design.Animation.spring) {
                    animateTimer = true
                }
            }
        }
    }
    
    private var timerCircle: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 20)
                .frame(width: 220, height: 220)

            Circle()
                .trim(from: 0, to: model.progress)
                .stroke(
                    Design.Colors.primaryGradient,
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(-90))
                .animation(Design.Animation.spring, value: model.progress)

            VStack(spacing: 8) {
                if model.isFasting {
                    Text(model.remainingString)
                        .font(Design.Typography.title)
                        .foregroundColor(Design.Colors.primary)
                        .animation(.easeInOut(duration: 0.2), value: model.timeRemaining)

                    Text("remaining")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                    
                    Text(model.elapsedString + " elapsed")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Ready to Fast")
                        .font(Design.Typography.headline)
                        .foregroundColor(.secondary)

                    Text("\(model.fastingWindowHours)h")
                        .font(Design.Typography.largeTitle)
                        .foregroundColor(Design.Colors.primary)
                }
            }
        }
        .scaleEffect(animateTimer ? 1.0 : 0.8)
        .opacity(animateTimer ? 1.0 : 0.0)
        .animation(Design.Animation.spring, value: animateTimer)
    }

    // MARK: - Status Card
    private var statusCard: some View {
        VStack(spacing: Design.Spacing.md) {
            HStack {
                Image(systemName: model.isFasting ? "timer" : "clock")
                    .foregroundColor(Design.Colors.primary)
                    .font(.title3)
                
                Text(model.isFasting ? "Fasting in Progress" : "Not Fasting")
                    .font(Design.Typography.headline)
                
                Spacer()
            }
            
            if model.isFasting, let start = model.fastingStart {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Started")
                            .font(Design.Typography.caption)
                            .foregroundColor(.secondary)
                        Text(start.formatted(date: .omitted, time: .shortened))
                            .font(Design.Typography.subheadline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Target")
                            .font(Design.Typography.caption)
                            .foregroundColor(.secondary)
                        Text("\(model.fastingWindowHours) hours")
                            .font(Design.Typography.subheadline)
                    }
                }
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(Design.Radius.large)
        .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Preset Windows
    private var presetWindowsSection: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Text("Quick Start")
                .font(Design.Typography.headline)
                .padding(.horizontal, Design.Spacing.xs)
            
            HStack(spacing: Design.Spacing.md) {
                PresetButton(hours: 16, label: "16:8") {
                    HapticManager.shared.mediumTap()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        model.startFast(hours: 16)
                    }
                }
                PresetButton(hours: 18, label: "18:6") {
                    HapticManager.shared.mediumTap()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        model.startFast(hours: 18)
                    }
                }
                PresetButton(hours: 20, label: "20:4") {
                    HapticManager.shared.mediumTap()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        model.startFast(hours: 20)
                    }
                }
            }
        }
    }
    
    // MARK: - Streak Card
    private var streakCard: some View {
        HStack(spacing: Design.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Design.Colors.accent.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "flame.fill")
                    .foregroundColor(Design.Colors.accent)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Streak")
                    .font(Design.Typography.caption)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(model.streak)")
                        .font(Design.Typography.title)
                        .foregroundColor(.primary)
                    Text("days")
                        .font(Design.Typography.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(model.completedFasts)")
                    .font(Design.Typography.headline)
                    .foregroundColor(Design.Colors.primary)
                Text("completed")
                    .font(Design.Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(Design.Radius.large)
        .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - History Card
    private var historyCard: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.md) {
            Text("Recent Fasts")
                .font(Design.Typography.headline)
            
            ForEach(model.fastingHistory.prefix(5)) { record in
                HStack {
                    Image(systemName: record.completed ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundColor(record.completed ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(Design.Typography.caption)
                        Text(record.actualHoursFormatted)
                            .font(Design.Typography.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    Text("\(record.targetHours)h target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(Design.Spacing.lg)
        .background(Design.Colors.cardBackground)
        .cornerRadius(Design.Radius.large)
        .shadow(color: Color.primary.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Action Button
    private var actionButton: some View {
        Button(action: {
            HapticManager.shared.mediumTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if model.isFasting {
                    model.endFast()
                } else {
                    model.startFast()
                }
            }
        }) {
            HStack {
                Image(systemName: model.isFasting ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title3)
                Text(model.isFasting ? "End Fast" : "Start Fast")
                    .font(Design.Typography.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(Design.Spacing.md)
            .background(
                model.isFasting ?
                LinearGradient(
                    colors: [Color.red, Color.red.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                ) :
                Design.Colors.primaryGradient
            )
            .cornerRadius(Design.Radius.large)
            .shadow(color: Design.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(SmoothButtonStyle())
    }
}

// MARK: - Preset Button
struct PresetButton: View {
    let hours: Int
    let label: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(Design.Animation.springFast) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            VStack(spacing: 6) {
                Text("\(hours)h")
                    .font(Design.Typography.headline)
                    .foregroundColor(Design.Colors.primary)
                Text(label)
                    .font(Design.Typography.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.Spacing.md)
            .background(Design.Colors.primary.opacity(0.1))
            .cornerRadius(Design.Radius.medium)
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(Design.Animation.springFast, value: isPressed)
    }
}
