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
            .onDisappear {
                stopRun()
            }
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

        let finalDistance = distanceMeters / 1000
        let finalTime = formattedTime
        print("Run complete: \(finalDistance) km in \(finalTime)")
    }

    private func resetRun() {
        distanceMeters = 0
        elapsedTime = 0
        previousLocation = nil
        routeCoordinates = []
        actionMessage = "Ready to start a new run." 
        region = MKCoordinateRegion(
            center: locationService.currentLocation?.coordinate ?? region.center,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
    }
}
