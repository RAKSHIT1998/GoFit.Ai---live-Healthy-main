//
//  CreateChallengeView.swift
//  GoFit.Ai - live Healthy
//
//  Create a challenge to compete with friends
//

import SwiftUI

struct CreateChallengeView: View {
    @EnvironmentObject var auth: AuthViewModel
    @ObservedObject private var friendsService = FriendsService.shared
    @StateObject private var challengeService = ChallengeService()
    @Environment(\.dismiss) private var dismiss

    @State private var challengeName = ""
    @State private var challengeDescription = ""
    @State private var selectedMetric: ChallengeMetric = .steps
    @State private var selectedDuration: ChallengeDuration = .oneWeek
    @State private var selectedFriends: Set<String> = []
    @State private var isCreating = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    enum ChallengeMetric: String, CaseIterable {
        case steps = "Steps"
        case calories = "Calories Burned"
        case workouts = "Workouts"
        case water = "Water (Liters)"
        case meals = "Meals Logged"

        var icon: String {
            switch self {
            case .steps: return "figure.walk"
            case .calories: return "flame.fill"
            case .workouts: return "dumbbell.fill"
            case .water: return "drop.fill"
            case .meals: return "fork.knife"
            }
        }

        var color: Color {
            switch self {
            case .steps: return .blue
            case .calories: return .orange
            case .workouts: return .red
            case .water: return .cyan
            case .meals: return .green
            }
        }

        var apiValue: String {
            switch self {
            case .steps: return "steps"
            case .calories: return "calories_burned"
            case .workouts: return "workouts"
            case .water: return "water"
            case .meals: return "meals_logged"
            }
        }
    }

    enum ChallengeDuration: Int, CaseIterable {
        case threeDays = 3
        case oneWeek = 7
        case twoWeeks = 14
        case oneMonth = 30

        var label: String {
            switch self {
            case .threeDays: return "3 Days"
            case .oneWeek: return "1 Week"
            case .twoWeeks: return "2 Weeks"
            case .oneMonth: return "1 Month"
            }
        }

        var emoji: String {
            switch self {
            case .threeDays: return "⚡"
            case .oneWeek: return "📅"
            case .twoWeeks: return "🗓️"
            case .oneMonth: return "🏆"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Challenge info section
                    nameSection

                    // Metric picker
                    metricSection

                    // Duration picker
                    durationSection

                    // Friend picker
                    friendPickerSection

                    // Create button
                    createButton
                }
                .padding(Design.Spacing.md)
            }
            .background(Design.Colors.background.ignoresSafeArea())
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                friendsService.fetchFriends { _ in }
            }
            .alert("Challenge Created! 🎉", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your challenge has been sent to your friends!")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Name Section
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Challenge Details", systemImage: "pencil.line")
                .font(Design.Typography.headline)

            TextField("Challenge name (e.g. Step Showdown)", text: $challengeName)
                .textFieldStyle(.roundedBorder)
                .font(Design.Typography.body)

            TextField("Description (optional)", text: $challengeDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .font(Design.Typography.body)
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Metric Section
    private var metricSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What to Track", systemImage: "target")
                .font(Design.Typography.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(ChallengeMetric.allCases, id: \.self) { metric in
                    Button {
                        selectedMetric = metric
                        HapticManager.shared.lightTap()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: metric.icon)
                                .font(.system(size: 22))
                                .foregroundColor(selectedMetric == metric ? .white : metric.color)

                            Text(metric.rawValue)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(selectedMetric == metric ? .white : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedMetric == metric
                                    ? AnyShapeStyle(LinearGradient(colors: [metric.color, metric.color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    : AnyShapeStyle(metric.color.opacity(0.08))
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Duration Section
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Duration", systemImage: "clock.fill")
                .font(Design.Typography.headline)

            HStack(spacing: 8) {
                ForEach(ChallengeDuration.allCases, id: \.self) { duration in
                    Button {
                        selectedDuration = duration
                        HapticManager.shared.lightTap()
                    } label: {
                        VStack(spacing: 4) {
                            Text(duration.emoji)
                                .font(.title3)
                            Text(duration.label)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(selectedDuration == duration ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedDuration == duration
                                    ? AnyShapeStyle(Design.Colors.primaryGradient)
                                    : AnyShapeStyle(Color.gray.opacity(0.08))
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Friend Picker
    private var friendPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Invite Friends", systemImage: "person.2.fill")
                    .font(Design.Typography.headline)
                Spacer()
                if !selectedFriends.isEmpty {
                    Text("\(selectedFriends.count) selected")
                        .font(Design.Typography.caption)
                        .foregroundColor(Design.Colors.primary)
                }
            }

            if friendsService.friends.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.slash")
                        .foregroundColor(.secondary)
                    Text("Add friends first to challenge them!")
                        .font(Design.Typography.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(friendsService.friends, id: \.id) { friend in
                            friendChip(friend)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
    }

    private func friendChip(_ friend: Friend) -> some View {
        let isSelected = selectedFriends.contains(friend.id)

        return Button {
            withAnimation(.spring(response: 0.3)) {
                if isSelected {
                    selectedFriends.remove(friend.id)
                } else {
                    selectedFriends.insert(friend.id)
                }
            }
            HapticManager.shared.lightTap()
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isSelected
                                    ? [Design.Colors.primary, Design.Colors.primary.opacity(0.7)]
                                    : [.gray.opacity(0.2), .gray.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(
                            Text(String(friend.username.prefix(1)).uppercased())
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(isSelected ? .white : .primary)
                        )

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Design.Colors.primary)
                            .background(Circle().fill(.white).frame(width: 14, height: 14))
                    }
                }

                Text(friend.username)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(isSelected ? Design.Colors.primary : .secondary)
                    .lineLimit(1)
            }
            .frame(width: 64)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create Button
    private var createButton: some View {
        Button {
            createChallenge()
        } label: {
            HStack(spacing: 10) {
                if isCreating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "flag.checkered")
                    Text("Start Challenge")
                        .fontWeight(.bold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if canCreate {
                        Design.Colors.primaryGradient
                    } else {
                        LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                    }
                }
            )
            .cornerRadius(16)
            .shadow(color: canCreate ? Design.Colors.primary.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
        }
        .disabled(!canCreate || isCreating)
        .buttonStyle(SmoothButtonStyle())
    }

    private var canCreate: Bool {
        !challengeName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Create Logic
    private func createChallenge() {
        isCreating = true
        HapticManager.shared.mediumTap()

        let startDate = Date()
        _ = Calendar.current.date(byAdding: .day, value: selectedDuration.rawValue, to: startDate) ?? startDate

        let friendIds = Array(selectedFriends)

        Task {
            do {
                try await challengeService.createChallenge(
                    name: challengeName.trimmingCharacters(in: .whitespaces),
                    description: challengeDescription.isEmpty ? nil : challengeDescription,
                    type: friendIds.count > 1 ? "group" : "personal_1v1",
                    metric: selectedMetric.apiValue,
                    targetValue: 0,
                    durationDays: selectedDuration.rawValue,
                    isGroupChallenge: friendIds.count > 1,
                    invitedUsers: friendIds.compactMap { Int($0) }
                )
                await MainActor.run {
                    isCreating = false
                    showSuccess = true
                    HapticManager.shared.success()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showError = true
                    HapticManager.shared.error()
                }
            }
        }
    }
}
