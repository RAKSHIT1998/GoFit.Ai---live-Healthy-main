//
//  FitMatchView.swift
//  GoFit.Ai - live Healthy
//
//  Tinder-like swipe interface for fitness matchmaking & competition
//

import SwiftUI

struct FitMatchView: View {
    @StateObject private var service = NearbyFitnessService.shared
    @EnvironmentObject var auth: AuthViewModel
    @State private var selectedTab: DiscoverTab = .discover
    
    enum DiscoverTab: CaseIterable {
        case discover, nearby, challenges
        
        var title: String {
            switch self {
            case .discover: return "Discover"
            case .nearby: return "Nearby"
            case .challenges: return "Challenges"
            }
        }
        
        var icon: String {
            switch self {
            case .discover: return "sparkles"
            case .nearby: return "location.fill"
            case .challenges: return "trophy.fill"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Tab picker
                    tabPicker
                    
                    // Content
                    TabView(selection: $selectedTab) {
                        discoverView
                            .tag(DiscoverTab.discover)
                        
                        nearbyListView
                            .tag(DiscoverTab.nearby)
                        
                        challengesView
                            .tag(DiscoverTab.challenges)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle("FitMatch")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                service.startDiscovery()
            }
        }
    }
    
    // MARK: - Tab Picker
    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(DiscoverTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                    HapticManager.shared.lightTap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.caption)
                        Text(tab.title)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(selectedTab == tab ? .white : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? Design.Colors.primary : Design.Colors.cardBackground)
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal, Design.Spacing.md)
        .padding(.vertical, Design.Spacing.sm)
    }
    
    // MARK: - Discover (Swipe Cards)
    private var discoverView: some View {
        ZStack {
            if service.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Finding fitness people near you...")
                        .font(Design.Typography.body)
                        .foregroundColor(.secondary)
                }
            } else if service.locationPermissionDenied {
                locationPermissionView
            } else if service.matchQueue.isEmpty {
                emptyDiscoverView
            } else {
                swipeCardStack
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Swipe Card Stack
    private var swipeCardStack: some View {
        ZStack {
            ForEach(Array(service.matchQueue.prefix(3).enumerated().reversed()), id: \.element.id) { index, person in
                SwipeCard(person: person, isTopCard: index == 0) { action in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        service.swipeAction(action, person: person)
                    }
                }
                .offset(y: CGFloat(index) * 8)
                .scaleEffect(1.0 - CGFloat(index) * 0.03)
                .zIndex(Double(3 - index))
            }
        }
        .padding(.horizontal, Design.Spacing.lg)
        .padding(.vertical, Design.Spacing.md)
    }
    
    // MARK: - Nearby List
    private var nearbyListView: some View {
        ScrollView {
            if service.nearbyPeople.isEmpty {
                emptyDiscoverView
            } else {
                LazyVStack(spacing: Design.Spacing.md) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(Design.Colors.primary)
                        Text("People within 20 km")
                            .font(Design.Typography.headline)
                        Spacer()
                        Text("\(service.nearbyPeople.count) found")
                            .font(Design.Typography.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, Design.Spacing.md)
                    
                    ForEach(service.nearbyPeople) { person in
                        NearbyPersonRow(person: person) {
                            service.sendChallenge(to: person, type: .steps)
                        }
                    }
                    .padding(.horizontal, Design.Spacing.md)
                }
                .padding(.vertical, Design.Spacing.md)
            }
        }
    }
    
    // MARK: - Challenges
    private var challengesView: some View {
        ScrollView {
            if service.activeChallenges.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "trophy.circle")
                        .font(.system(size: 60))
                        .foregroundColor(Design.Colors.accent.opacity(0.5))
                    Text("No Active Challenges")
                        .font(Design.Typography.title2)
                    Text("Swipe right on someone to challenge them!")
                        .font(Design.Typography.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                LazyVStack(spacing: Design.Spacing.md) {
                    ForEach(service.activeChallenges) { challenge in
                        ChallengeCard(challenge: challenge)
                    }
                }
                .padding(Design.Spacing.md)
            }
        }
    }
    
    // MARK: - Empty / Permission Views
    private var emptyDiscoverView: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(colors: [Design.Colors.primary, Design.Colors.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            Text("No one nearby... yet!")
                .font(Design.Typography.title2)
                .foregroundColor(.primary)
            
            Text("We'll keep looking. People within 20 km who use GoFit will show up here.")
                .font(Design.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                Task {
                    await service.fetchNearbyPeople()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Design.Colors.primary)
                .cornerRadius(Design.Radius.medium)
            }
            .buttonStyle(SmoothButtonStyle())
        }
    }
    
    private var locationPermissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Location Access Needed")
                .font(Design.Typography.title2)
            
            Text("Allow location access to discover fitness enthusiasts within 20 km of you.")
                .font(Design.Typography.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Settings")
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Design.Colors.primary)
                    .cornerRadius(Design.Radius.medium)
            }
            .buttonStyle(SmoothButtonStyle())
        }
    }
}

// MARK: - Swipe Card
struct SwipeCard: View {
    let person: NearbyPerson
    let isTopCard: Bool
    let onAction: (SwipeAction) -> Void
    
    @State private var offset: CGSize = .zero
    @State private var rotation: Double = 0
    @State private var showChallengeType = false
    
    private var swipeDirection: SwipeAction? {
        if offset.width > 100 { return .challenge }
        if offset.width < -100 { return .skip }
        return nil
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: cardGradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Avatar and content
            VStack(spacing: 0) {
                Spacer()
                
                // Large avatar
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 120, height: 120)
                    
                    Text(person.displayName.prefix(1).uppercased())
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 16)
                
                // Name & Info
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Text(person.displayName)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        if let age = person.age {
                            Text("\(age)")
                                .font(.title3.weight(.medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text(person.distanceText)
                            .font(.subheadline)
                    }
                    .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer().frame(height: 20)
                
                // Stats row
                HStack(spacing: 20) {
                    statBubble(icon: "flame.fill", value: "\(person.currentStreak)", label: "Streak", color: .orange)
                    statBubble(icon: "star.fill", value: "Lv.\(person.level)", label: person.levelTitle, color: .yellow)
                    statBubble(icon: "bolt.fill", value: "\(person.totalPoints)", label: "Points", color: .cyan)
                }
                .padding(.horizontal)
                
                Spacer().frame(height: 16)
                
                // Workout tag + bio
                VStack(spacing: 8) {
                    if let workout = person.favoriteWorkout {
                        HStack(spacing: 6) {
                            Image(systemName: "dumbbell.fill")
                                .font(.caption)
                            Text(workout)
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.2))
                        .cornerRadius(20)
                    }
                    
                    if let bio = person.bio {
                        Text(bio)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                
                Spacer().frame(height: 24)
                
                // Action buttons
                if isTopCard {
                    actionButtons
                }
                
                Spacer().frame(height: 16)
            }
            
            // Swipe indicator overlays
            if isTopCard {
                swipeOverlays
            }
        }
        .frame(height: 520)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
        .offset(x: isTopCard ? offset.width : 0, y: isTopCard ? offset.height : 0)
        .rotationEffect(.degrees(isTopCard ? rotation : 0))
        .gesture(isTopCard ? dragGesture : nil)
    }
    
    // MARK: - Card Gradient
    private var cardGradientColors: [Color] {
        let hue = Double(abs(person.id.hashValue) % 360) / 360.0
        return [
            Color(hue: hue, saturation: 0.6, brightness: 0.7),
            Color(hue: (hue + 0.1).truncatingRemainder(dividingBy: 1.0), saturation: 0.7, brightness: 0.5),
            Color(hue: (hue + 0.15).truncatingRemainder(dividingBy: 1.0), saturation: 0.8, brightness: 0.35)
        ]
    }
    
    // MARK: - Stat Bubble
    private func statBubble(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(0.12))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 20) {
            // Skip
            Button {
                HapticManager.shared.lightTap()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    offset = CGSize(width: -400, height: 0)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onAction(.skip)
                    offset = .zero
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.2))
                    .clipShape(Circle())
            }
            
            // Super Like
            Button {
                HapticManager.shared.mediumTap()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    offset = CGSize(width: 0, height: -400)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onAction(.superLike)
                    offset = .zero
                }
            } label: {
                Image(systemName: "star.fill")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.yellow)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.2))
                    .clipShape(Circle())
            }
            
            // Challenge
            Button {
                HapticManager.shared.mediumTap()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    offset = CGSize(width: 400, height: 0)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onAction(.challenge)
                    offset = .zero
                }
            } label: {
                Image(systemName: "bolt.fill")
                    .font(.title2.weight(.bold))
                    .foregroundColor(Design.Colors.primary)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.2))
                    .clipShape(Circle())
            }
        }
    }
    
    // MARK: - Swipe Overlays
    private var swipeOverlays: some View {
        ZStack {
            // Challenge overlay (right)
            RoundedRectangle(cornerRadius: 24)
                .fill(Design.Colors.success.opacity(0.3))
                .overlay(
                    VStack {
                        Image(systemName: "bolt.circle.fill")
                            .font(.system(size: 60))
                        Text("CHALLENGE!")
                            .font(.largeTitle.weight(.black))
                    }
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(-15))
                )
                .opacity(offset.width > 50 ? min(Double(offset.width - 50) / 100, 1) : 0)
            
            // Skip overlay (left)
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.red.opacity(0.3))
                .overlay(
                    VStack {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 60))
                        Text("SKIP")
                            .font(.largeTitle.weight(.black))
                    }
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(15))
                )
                .opacity(offset.width < -50 ? min(Double(-offset.width - 50) / 100, 1) : 0)
        }
    }
    
    // MARK: - Drag Gesture
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
                rotation = Double(value.translation.width) / 20
            }
            .onEnded { value in
                let threshold: CGFloat = 120
                
                if value.translation.width > threshold {
                    // Swipe right → Challenge
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = CGSize(width: 500, height: value.translation.height)
                    }
                    HapticManager.shared.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onAction(.challenge)
                        offset = .zero
                        rotation = 0
                    }
                } else if value.translation.width < -threshold {
                    // Swipe left → Skip
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        offset = CGSize(width: -500, height: value.translation.height)
                    }
                    HapticManager.shared.lightTap()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onAction(.skip)
                        offset = .zero
                        rotation = 0
                    }
                } else {
                    // Snap back
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        offset = .zero
                        rotation = 0
                    }
                }
            }
    }
}

// MARK: - Nearby Person Row
struct NearbyPersonRow: View {
    let person: NearbyPerson
    let onChallenge: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Design.Colors.primary.opacity(0.6), Design.Colors.accent.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                
                Text(person.displayName.prefix(1).uppercased())
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(person.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Lv.\(person.level)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Design.Colors.primary)
                        .cornerRadius(8)
                }
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(person.distanceText)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    if let workout = person.favoriteWorkout {
                        HStack(spacing: 4) {
                            Image(systemName: "dumbbell.fill")
                                .font(.caption2)
                            Text(workout)
                                .font(.caption)
                        }
                        .foregroundColor(Design.Colors.primary)
                    }
                }
                
                HStack(spacing: 8) {
                    Label("\(person.currentStreak)🔥", systemImage: "flame.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    
                    Label("\(person.totalPoints) pts", systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            
            Spacer()
            
            Button {
                HapticManager.shared.mediumTap()
                onChallenge()
            } label: {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Design.Colors.primary)
                    .clipShape(Circle())
            }
            .buttonStyle(SmoothButtonStyle())
        }
        .padding(Design.Spacing.md)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Challenge Card
struct ChallengeCard: View {
    let challenge: FitnessChallenge
    
    var body: some View {
        VStack(spacing: Design.Spacing.md) {
            HStack {
                // Challenge type
                Image(systemName: challenge.type.icon)
                    .font(.title2)
                    .foregroundColor(challenge.type.color)
                    .frame(width: 48, height: 48)
                    .background(challenge.type.color.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(challenge.type.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("vs \(challenge.challengedName ?? "Opponent")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status badge
                Text(challenge.status.rawValue.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusColor)
                    .cornerRadius(12)
            }
            
            // Score
            HStack {
                VStack(spacing: 2) {
                    Text("You")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(challenge.challengerScore)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(Design.Colors.primary)
                    Text(challenge.type.unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                
                Text("VS")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 2) {
                    Text(challenge.challengedName?.components(separatedBy: " ").first ?? "Them")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(challenge.challengedScore)")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.orange)
                    Text(challenge.type.unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, Design.Spacing.sm)
            .background(Design.Colors.cardBackground)
            .cornerRadius(12)
            
            // Time remaining
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption2)
                Text(timeRemainingText)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(Design.Spacing.md)
        .background(Design.Colors.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    private var statusColor: Color {
        switch challenge.status {
        case .pending: return .orange
        case .active: return Design.Colors.primary
        case .completed: return Design.Colors.success
        case .declined: return .red
        }
    }
    
    private var timeRemainingText: String {
        let remaining = challenge.expiresAt.timeIntervalSince(Date())
        if remaining <= 0 { return "Expired" }
        let days = Int(remaining / 86400)
        let hours = Int(remaining.truncatingRemainder(dividingBy: 86400) / 3600)
        if days > 0 { return "\(days)d \(hours)h remaining" }
        return "\(hours)h remaining"
    }
}
