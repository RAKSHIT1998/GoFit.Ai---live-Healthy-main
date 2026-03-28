import SwiftUI

struct DeviceIntegrationView: View {
    @StateObject private var healthKit = HealthKitService.shared
    @State private var syncStatus: String = ""
    @State private var isSyncing = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "applewatch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.primary)
                    .padding(.top, 32)
                Text("Device Integration")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Sync your workouts, steps, heart rate, and more with Apple Health and Apple Watch. Live stats and background sync supported.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Divider()
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: healthKit.isAuthorized ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(healthKit.isAuthorized ? .green : .orange)
                        Text(healthKit.isAuthorized ? "HealthKit Authorized" : "HealthKit Not Authorized")
                            .fontWeight(.semibold)
                    }
                    if !healthKit.isAuthorized {
                        Button(action: requestHealthKit) {
                            HStack {
                                Image(systemName: "lock.open")
                                Text("Enable HealthKit")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                Divider()
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Manual Sync")
                            .fontWeight(.semibold)
                    }
                    Button(action: syncNow) {
                        if isSyncing {
                            ProgressView()
                        } else {
                            Text("Sync Now")
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                    if !syncStatus.isEmpty {
                        Text(syncStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Device Integration")
        }
    }
    
    private func requestHealthKit() {
        Task {
            do {
                try await healthKit.requestAuthorization()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func syncNow() {
        isSyncing = true
        syncStatus = ""
        errorMessage = nil
        Task {
            do {
                try await healthKit.readTodayData()
                try await healthKit.syncToBackend()
                syncStatus = "Synced successfully at \(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short))"
            } catch {
                errorMessage = error.localizedDescription
            }
            isSyncing = false
        }
    }
}

#Preview {
    DeviceIntegrationView()
}
