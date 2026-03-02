//
//  SleepCard.swift
//  GoFit.Ai - live Healthy
//
//  Compact sleep summary card for home dashboard
//

import SwiftUI

struct SleepCard: View {
    @ObservedObject private var sleepManager = SleepManager.shared
    @State private var showingSleepTracker = false
    @State private var animateMoon = false
    
    var body: some View {
        Button {
            HapticManager.shared.lightTap()
            showingSleepTracker = true
        } label: {
            VStack(alignment: .leading, spacing: Design.Spacing.md) {
                // Header
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.purple)
                                .rotationEffect(.degrees(animateMoon ? -10 : 10))
                        }
                        
                        Text("Sleep")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Content
                if let today = sleepManager.todayEntry {
                    // Show last night's sleep
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(today.durationFormatted)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("Last night")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Quality indicator
                        VStack(spacing: 2) {
                            Text(today.quality.emoji)
                                .font(.title2)
                            Text(today.quality.label)
                                .font(.caption2)
                                .foregroundColor(today.quality.color)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(today.quality.color.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Goal progress
                    VStack(alignment: .leading, spacing: 4) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.2))
                                
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple, Design.Colors.primary],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * sleepManager.goalProgress)
                            }
                        }
                        .frame(height: 6)
                        
                        HStack {
                            Text("\(Int(sleepManager.goalProgress * 100))% of \(Int(sleepManager.sleepGoal))h goal")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if let score = sleepManager.weeklyStats?.sleepScore {
                                Text("Score: \(score)")
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.purple)
                            }
                        }
                    }
                } else {
                    // No sleep logged
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No sleep logged")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Tap to log last night's sleep")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                }
            }
            .padding(Design.Spacing.lg)
            .background(Design.Colors.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.primary.opacity(0.06), radius: 10, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSleepTracker) {
            SleepTrackerView()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                animateMoon = true
            }
        }
    }
}

// MARK: - Mini Sleep Widget for Quick Actions
struct MiniSleepWidget: View {
    @ObservedObject private var sleepManager = SleepManager.shared
    @State private var showingSleepTracker = false
    
    var body: some View {
        Button {
            HapticManager.shared.mediumTap()
            showingSleepTracker = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(
                        LinearGradient(
                            colors: [.purple, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                
                Text("Sleep")
                    .font(Design.Typography.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.Spacing.md)
            .background(Design.Colors.cardBackground)
            .cornerRadius(16)
            .shadow(color: Color.primary.opacity(0.06), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(SmoothButtonStyle())
        .sheet(isPresented: $showingSleepTracker) {
            SleepTrackerView()
        }
    }
}

#Preview {
    VStack {
        SleepCard()
        MiniSleepWidget()
    }
    .padding()
    .background(Color.gray.opacity(0.1))
}
