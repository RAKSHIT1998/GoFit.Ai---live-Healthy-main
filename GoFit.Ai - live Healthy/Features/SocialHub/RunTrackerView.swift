import SwiftUI
import MapKit

struct RunTrackerView: View {
    @ObservedObject private var localUserStore = LocalUserStore.shared
    @StateObject private var locationService = LocationService.shared

    @AppStorage("run_unit_preference") private var preferredUnitRaw = DistanceUnit.kilometers.rawValue
    private var preferredUnit: DistanceUnit { DistanceUnit(rawValue: preferredUnitRaw) ?? .kilometers }

    @State private var isTracking = false
    @State private var elapsedTime: TimeInterval = 0
    @State private var distanceMeters: Double = 0
    @State private var totalAscent: Double = 0
    @State private var totalDescent: Double = 0
    @State private var caloriesBurned: Double = 0
    @State private var previousLocation: CLLocation?
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var runSessions: [RunSession] = []
    @State private var milestoneMessage: String?

    @State private var timer: Timer? = nil
    @State private var actionMessage: String = ""
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.334_900, longitude: -122.009_020),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    @State private var showSummarySheet = false
    @State private var lastSavedSession: RunSession?
    @State private var errorDescription: String?

    @State private var manualDistanceText = ""
    @State private var manualDurationText = ""

    private var formattedDistance: String {
        let distance = preferredUnit == .kilometers ? distanceMeters/1000 : distanceMeters * 0.000621371
        return String(format: "%.2f %@", distance, preferredUnit.label)
    }

    private var formattedPace: String {
        let pace = distanceMeters > 0 ? (elapsedTime / (distanceMeters / 1000)) : 0
        let convertedPace = preferredUnit == .kilometers ? pace : pace * 0.621371
        let minutes = Int(convertedPace)
        let seconds = Int((convertedPace - Double(minutes)) * 60)
        return String(format: "%02d:%02d %@", minutes, seconds, preferredUnit.paceLabel)
    }

    private var formattedTime: String {
        let hrs = Int(elapsedTime) / 3600
        let mins = (Int(elapsedTime) % 3600) / 60
        let secs = Int(elapsedTime) % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    runMap
                    runSummaryCards
                    unitSelection

                    if let milestone = milestoneMessage {
                        Text(milestone)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(12)
                            .foregroundColor(.green)
                            .onTapGesture { milestoneMessage = nil }
                    }

                    if let error = errorDescription {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Location unavailable")
                                .font(.headline)
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Button("Open Settings") {
                                openSystemSettings()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(12)
                        .background(Color.red.opacity(0.08))
                        .cornerRadius(12)
                    }

                    runButtons
                        .padding(.top, 4)

                    manualRunEntry

                    if !runSessions.isEmpty {
                        recentRuns
                    }

                    Spacer(minLength: 30)
                }
                .padding(16)
            }
            .navigationTitle("Run Tracker")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { stopRun() }
                }
            }
            .sheet(isPresented: $showSummarySheet) { runSummarySheet }
            .onChange(of: locationService.currentLocation) { oldLocation, newLocation in
                guard isTracking, let location = newLocation else {
                    if isTracking {
                        errorDescription = "Waiting for GPS fix... switch to manual run if your device has no signal."
                    }
                    return
                }
                errorDescription = nil
                appendLocation(location)
            }
            .onChange(of: locationService.authorizationStatus) { oldStatus, status in
                if status == .denied || status == .restricted {
                    errorDescription = "Location permission denied. Allow location in Settings or use manual run."
                }
            }
            .onAppear { loadRunSessions() }
            .onDisappear { stopRun() }
        }
    }

    private var runMap: some View {
        Map(position: $region, interactionModes: .all, showsUserLocation: true, userTrackingMode: .constant(.follow)) {
            if !routeCoordinates.isEmpty {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(Color.blue, lineWidth: 4)
            }
        }
        .frame(height: 260)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.15), lineWidth: 1))
    }

    private var runSummaryCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                runStatCard(label: "Time", value: formattedTime)
                runStatCard(label: "Distance", value: formattedDistance)
            }
            HStack(spacing: 12) {
                runStatCard(label: "Pace", value: formattedPace)
                runStatCard(label: "Calories", value: String(format: "%.0f kcal", caloriesBurned))
            }
            HStack(spacing: 12) {
                runStatCard(label: "Ascent", value: String(format: "%.0f m", totalAscent))
                runStatCard(label: "Descent", value: String(format: "%.0f m", totalDescent))
            }
        }
    }

    private var unitSelection: some View {
        Picker("Unit", selection: $preferredUnitRaw) {
            ForEach(DistanceUnit.allCases) { unit in
                Text(unit == .kilometers ? "Metric (km)" : "Imperial (mi)").tag(unit.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: preferredUnitRaw) { _ in
            // persists automatically via AppStorage
        }
    }

    private var runButtons: some View {
        VStack(spacing: 10) {
            Text(actionMessage)
                .font(.caption2)
                .foregroundColor(.secondary)

            Button(action: {
                if isTracking { stopRun() } else { startRun() }
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
                Button("Reset") { resetRun() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var manualRunEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Manual Run (offline)")
                .font(.subheadline)
                .fontWeight(.semibold)

            TextField("Distance in km", text: $manualDistanceText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            TextField("Duration in minutes", text: $manualDurationText)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)

            Button("Save Manual Run") { saveManualRun() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var recentRuns: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Runs")
                .font(.headline)

            ForEach(runSessions.prefix(3)) { session in
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.date, style: .date)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(String(format: "%.2f %@ • %@", session.distance(for: preferredUnit), preferredUnit.label, session.paceFormatted(for: preferredUnit)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f kcal", session.calories))
                        .font(.caption2)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .contextMenu { shareSession(session) }
            }
        }
        .padding(.top, 8)
    }

    // Removed doneButton property; ToolbarItem is now inline in .toolbar

    @ViewBuilder
    private var runSummarySheet: some View {
        if let session = lastSavedSession {
            VStack(spacing: 16) {
                Text("Run Summary")
                    .font(.title)
                    .fontWeight(.bold)

                Text(String(format: "%.2f %@ in %@", session.distance(for: preferredUnit), preferredUnit.label, session.durationSeconds.stringFromTimeInterval()))
                    .font(.headline)

                Text("Pace: \(session.paceFormatted(for: preferredUnit))")
                Text("Ascent: \(Int(session.ascentMeters)) m")
                Text("Descent: \(Int(session.descentMeters)) m")
                Text("Calories: \(Int(session.calories)) kcal")

                ShareLink(item: runShareText(session), preview: SharePreview("Run data")) {
                    Label("Share Run", systemImage: "square.and.arrow.up")
                }

                shareSession(session)

                Button("Close") { showSummarySheet = false }
                    .buttonStyle(.bordered)
            }
            .padding(16)
        } else {
            Text("No summary available")
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

    private func appendLocation(_ location: CLLocation) {
        if routeCoordinates.isEmpty { region.center = location.coordinate }

        if let previous = previousLocation {
            distanceMeters += location.distance(from: previous)
            let altitudeDiff = location.altitude - previous.altitude
            if altitudeDiff > 0 { totalAscent += altitudeDiff } else { totalDescent += abs(altitudeDiff) }
        }

        previousLocation = location
        routeCoordinates.append(location.coordinate)
        region.center = location.coordinate
        calculateCalories()
    }

    private func calculateCalories() {
        let weightKg = localUserStore.userProfile?.weightKg ?? 70.0
        let met = 9.0
        caloriesBurned = (met * 3.5 * weightKg / 200) * (elapsedTime / 60)
    }

    private func loadRunSessions() {
        let stored = RunHistoryStore.shared.fetchRuns(limit: 50)
        runSessions = stored
    }

    private func saveRunSessions() {
        if let data = try? JSONEncoder().encode(runSessions) {
            UserDefaults.standard.set(data, forKey: "run_sessions")
        }
    }

    private func checkMilestone(for session: RunSession) {
        let existing = runSessions.map { Int($0.distanceKm) }
        let milestones = [1, 5, 10, 21, 42]

        if let found = milestones.first(where: { session.distanceKm >= Double($0) && !existing.contains($0) }) {
            milestoneMessage = "🏅 Milestone unlocked: \(found) km run!"
            NotificationService.shared.sendNowNotification(title: "Milestone reached!", body: milestoneMessage ?? "")
            StreakManager.shared.awardPoints(200)
            actionMessage = "Great job! You unlocked a run milestone."
        }
    }

    private func startRun() {
        guard !isTracking else { return }

        locationService.requestPermission()
        if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
            errorDescription = "Location permission not granted. Please enable it in Settings or use manual mode."
        }

        locationService.startUpdating()
        previousLocation = nil
        routeCoordinates = []
        elapsedTime = 0
        distanceMeters = 0
        totalAscent = 0
        totalDescent = 0
        caloriesBurned = 0
        actionMessage = "Tracking started. Stay safe and hydrate!"

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in elapsedTime += 1 }

        isTracking = true
    }

    private func stopRun() {
        guard isTracking else { return }

        isTracking = false
        locationService.stopUpdating()
        timer?.invalidate(); timer = nil

        let finalDistanceKm = distanceMeters / 1000
        let paceMinPerKm = finalDistanceKm > 0 ? elapsedTime / (finalDistanceKm * 60) : 0
        let run = RunSession(
            id: UUID().uuidString,
            date: Date(),
            distanceKm: finalDistanceKm,
            durationSeconds: elapsedTime,
            calories: caloriesBurned,
            ascentMeters: totalAscent,
            descentMeters: totalDescent,
            paceMinPerKm: paceMinPerKm,
            route: routeCoordinates.map { RunPoint(latitude: $0.latitude, longitude: $0.longitude) }
        )

        checkMilestone(for: run)
        RunHistoryStore.shared.storeRun(run)

        runSessions.insert(run, at: 0)
        saveRunSessions()

        actionMessage = "Run stopped. Total: \(String(format: "%.2f %@", run.distance(for: preferredUnit), preferredUnit.label)) in \(formattedTime)."
        lastSavedSession = run
        showSummarySheet = true
    }

    private func resetRun() {
        isTracking = false
        locationService.stopUpdating()
        timer?.invalidate(); timer = nil

        elapsedTime = 0
        distanceMeters = 0
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

    private func saveManualRun() {
        guard let distanceKm = Double(manualDistanceText), let minutes = Double(manualDurationText) else {
            actionMessage = "Enter valid manual distance and time."
            return
        }

        let durationSeconds = minutes * 60
        let paceKM = durationSeconds / (distanceKm * 60)
        let calories = calculateManualCalories(durationSeconds: durationSeconds)

        let session = RunSession(
            id: UUID().uuidString,
            date: Date(),
            distanceKm: distanceKm,
            durationSeconds: durationSeconds,
            calories: calories,
            ascentMeters: 0,
            descentMeters: 0,
            paceMinPerKm: paceKM,
            route: []
        )

        runSessions.insert(session, at: 0)
        RunHistoryStore.shared.storeRun(session)
        saveRunSessions()

        actionMessage = "Manual run saved: \(String(format: "%.2f %@", session.distance(for: preferredUnit), preferredUnit.label))."
        manualDistanceText = ""
        manualDurationText = ""
        lastSavedSession = session
        showSummarySheet = true
    }

    private func calculateManualCalories(durationSeconds: Double) -> Double {
        let weightKg = localUserStore.userProfile?.weightKg ?? 70.0
        let met = 9.0
        return (met * 3.5 * weightKg / 200) * (durationSeconds / 60)
    }

    private func runShareText(_ session: RunSession) -> String {
        let formattedDistance = String(format: "%.2f %@", session.distance(for: preferredUnit), preferredUnit.label)
        let duration = session.durationSeconds.stringFromTimeInterval()
        let pace = session.paceFormatted(for: preferredUnit)

        return "Run on \(DateFormatter.localizedString(from: session.date, dateStyle: .short, timeStyle: .short)):\nDistance: \(formattedDistance)\nTime: \(duration)\nPace: \(pace)\nCalories: \(Int(session.calories)) kcal" +
            "\nRoute points: \(session.route.count)"
    }

    private func shareSession(_ session: RunSession) -> some View {
        let routeGPX = gpxString(for: session)
        return Group {
            Button(action: {
                let url = saveGPXToTempFile(data: routeGPX.data(using: .utf8) ?? Data(), name: "run_route_\(session.id).gpx")
                if let url = url {
                    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    UIApplication.shared.topMostViewController()?.present(activityVC, animated: true, completion: nil)
                }
            }) {
                Label("Export GPX", systemImage: "square.and.arrow.up")
            }
        }
    }

    private func gpxString(for session: RunSession) -> String {
        let header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<gpx version=\"1.1\" creator=\"GoFit\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n"
        let footer = "</gpx>"

        let pathPoints = session.route.map { point -> String in
            let latStr = String(format: "%.6f", point.latitude)
            let lonStr = String(format: "%.6f", point.longitude)
            return "<trkpt lat=\"\(latStr)\" lon=\"\(lonStr)\"/>"
        }.joined()

        return header + "<trk><name>Run \(session.date)</name><trkseg>" + pathPoints + "</trkseg></trk>" + footer
    }

    private func saveGPXToTempFile(data: Data, name: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url)
            return url
        } catch {
            print("Failed to export GPX: \(error)")
            return nil
        }
    }

    private func openSystemSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

private extension TimeInterval {
    func stringFromTimeInterval() -> String {
        let ti = Int(self)
        let minutes = (ti / 60) % 60
        let hours = ti / 3600
        let seconds = ti % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

private extension UIApplication {
    func topMostViewController() -> UIViewController? {
        guard let root = connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first?.rootViewController else { return nil }

        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
