import SwiftUI
import MapKit

struct RunTrackerView: View {
    @ObservedObject private var localUserStore = LocalUserStore.shared
    @StateObject private var locationService = LocationService.shared

    @State private var isTracking = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var distanceMeters: Double = 0
    @State private var totalAscent: Double = 0
    @State private var totalDescent: Double = 0
    @State private var caloriesBurned: Double = 0
    @State private var previousLocation: CLLocation?
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var runSessions: [RunSession] = []
    @State private var milestoneMessage: String? = nil

    @State private var timer: Timer? = nil
    @State private var actionMessage: String = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.334_900, longitude: -122.009_020),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    private var formattedDistance: String {
        String(format: "%.2f", distanceMeters / 1000)
    }

    private var formattedTime: String {
        let hrs = Int(elapsedTime) / 3600
        let mins = (Int(elapsedTime) % 3600) / 60
        let secs = Int(elapsedTime) % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Map(coordinateRegion: $region, interactionModes: .all, showsUserLocation: true, userTrackingMode: .constant(.follow)) {
                    if !routeCoordinates.isEmpty {
                        MapPolyline(coordinates: routeCoordinates)
                            .stroke(Color.blue, lineWidth: 4)
                    }
                }
                .frame(height: 240)
                .cornerRadius(16)
                .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    )

                HStack(spacing: 20) {
                    runStatCard(label: "Time", value: formattedTime)
                    runStatCard(label: "Distance (km)", value: formattedDistance)
                }

                HStack(spacing: 20) {
                    runStatCard(label: "Calories", value: String(format: "%.0f kcal", caloriesBurned))
                    runStatCard(label: "Ascent", value: String(format: "%.0f m", totalAscent))
                    runStatCard(label: "Descent", value: String(format: "%.0f m", totalDescent))
                }

                if let milestone = milestoneMessage {
                    Text(milestone)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(12)
                        .foregroundColor(.green)
                        .onTapGesture {
                            milestoneMessage = nil
                        }
                }

                if !runSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Runs")
                            .font(.headline)
                        ForEach(runSessions.prefix(3)) { session in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(session.date, style: .date)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text("\(String(format: "%.2f", session.distanceKm)) km • \(session.paceFormatted)/km")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(Int(session.calories)) kcal")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.top, 8)
                }

                VStack(spacing: 12) {
                    Text(actionMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button(action: {
                        if isTracking {
                            stopRun()
                        } else {
                            startRun()
                        }
                    }) {
                        Text(isTracking ? "Stop Run" : "Start Run")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isTracking ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                    if !isTracking && elapsedTime > 0 {
                        Button("Reset") {
                            resetRun()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(16)
            .navigationTitle("Run Tracker")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        stopRun()
                    }
                }
            }
            .onChange(of: locationService.currentLocation) { newLocation in
                guard isTracking, let location = newLocation else { return }

                if routeCoordinates.isEmpty {
                    region.center = location.coordinate
                }

                if let previous = previousLocation {
                    distanceMeters += location.distance(from: previous)
                    let altitudeDiff = location.altitude - previous.altitude
                    if altitudeDiff > 0 {
                        totalAscent += altitudeDiff
                    } else {
                        totalDescent += abs(altitudeDiff)
                    }
                }

                previousLocation = location
                routeCoordinates.append(location.coordinate)
                region.center = location.coordinate
                calculateCalories()
            }
            .onAppear {
                loadRunSessions()
            }
            .onDisappear {
                stopRun()
            }
        }
    }

    private func calculateCalories() -> Double {
        let kcalPerMinute: Double
        let weightKg = localUserStore.userProfile?.weightKg ?? 70.0
        let met = 9.0 // moderate run
        kcalPerMinute = (met * 3.5 * weightKg) / 200.0
        return kcalPerMinute * (elapsedTime / 60.0)
    }

    private func loadRunSessions() {
        guard let data = UserDefaults.standard.data(forKey: "run_sessions") else { return }
        if let saved = try? JSONDecoder().decode([RunSession].self, from: data) {
            runSessions = saved
        }
    }

    private func saveRunSessions() {
        if let data = try? JSONEncoder().encode(runSessions) {
            UserDefaults.standard.set(data, forKey: "run_sessions")
        }
    }

    private func checkMilestone(for session: RunSession) {
        let distance = session.distanceKm
        let existingMilestones = runSessions.map { Int($0.distanceKm) }
        let possibleMilestones = [1, 5, 10, 21, 42]

        let milestone = possibleMilestones.first(where: { m in
            distance >= Double(m) && !existingMilestones.contains(m)
        })

        if let found = milestone {
            milestoneMessage = "🏅 Milestone unlocked: \(found) km run!"
            NotificationService.shared.sendNowNotification(title: "Milestone reached!", body: milestoneMessage!)
            StreakManager.shared.awardPoints(200)
        }
    }

    private func runStatCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }

    private func startRun() {
        guard !isTracking else { return }
        locationService.requestPermission()
        locationService.startUpdating()
        previousLocation = nil
        routeCoordinates = []
        elapsedTime = 0
        distanceMeters = 0
        actionMessage = "Tracking started. Stay safe and hydrate!"

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
        }

        isTracking = true
    }

    private func stopRun() {
        guard isTracking else { return }
        isTracking = false
        locationService.stopUpdating()
        timer?.invalidate()
        timer = nil
        actionMessage = "Run stopped. Total: \(formattedDistance) km in \(formattedTime)."

        caloriesBurned = calculateCalories()

        let finalDistance = distanceMeters / 1000
        let finalTimeInSeconds = elapsedTime
        let finalTime = formattedTime
        let averagePace = finalDistance > 0 ? finalTimeInSeconds / (finalDistance * 60) : 0

        let routePoints = routeCoordinates.map { RunPoint(latitude: $0.latitude, longitude: $0.longitude) }
        let session = RunSession(
            id: UUID().uuidString,
            date: Date(),
            distanceKm: finalDistance,
            durationSeconds: finalTimeInSeconds,
            calories: caloriesBurned,
            ascentMeters: totalAscent,
            descentMeters: totalDescent,
            paceMinPerKm: averagePace,
            route: routePoints
        )

        checkMilestone(for: session)
        runSessions.insert(session, at: 0)
        saveRunSessions()

        print("Run complete: \(finalDistance) km in \(finalTime) with \(caloriesBurned) kcal")
    }

    private func resetRun() {
        distanceMeters = 0
        elapsedTime = 0
        totalAscent = 0
        totalDescent = 0
        caloriesBurned = 0
        previousLocation = nil
        routeCoordinates = []
        actionMessage = "Ready to start a new run." 
        region = MKCoordinateRegion(
            center: locationService.currentLocation?.coordinate ?? region.center,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
}

struct RunPoint: Codable {
    let latitude: Double
    let longitude: Double
}

struct RunSession: Codable, Identifiable {
    let id: String
    let date: Date
    let distanceKm: Double
    let durationSeconds: TimeInterval
    let calories: Double
    let ascentMeters: Double
    let descentMeters: Double
    let paceMinPerKm: Double
    let route: [RunPoint]

    var paceFormatted: String {
        let minutes = Int(paceMinPerKm)
        let seconds = Int((paceMinPerKm - Double(minutes)) * 60)
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
