import Foundation
import HealthKit
import UIKit

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    
    private let healthStore = HKHealthStore()
    
    @Published var isAuthorized = false
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Double = 0
    @Published var todayRestingCalories: Double = 0
    @Published var todayWalkingRunningDistance: Double = 0
    @Published var todayCyclingDistance: Double = 0
    @Published var todayFlightsClimbed: Int = 0
    @Published var sleepHours: Double = 0
    @Published var mindfulMinutes: Double = 0
    @Published var restingHeartRate: Double = 0
    @Published var averageHeartRate: Double = 0
    @Published var heartRateVariability: Double = 0
    @Published var bloodOxygen: Double = 0
    @Published var respiratoryRate: Double = 0
    @Published var bodyWeightKg: Double = 0
    @Published var bodyMassIndex: Double = 0
    @Published var bodyFatPercentage: Double = 0
    @Published var bodyTemperatureCelsius: Double = 0
    @Published var systolicBloodPressure: Double = 0
    @Published var diastolicBloodPressure: Double = 0
    
    // Use nonisolated(unsafe) for Task to allow access from deinit
    nonisolated(unsafe) private var periodicSyncTask: Task<Void, Never>?
    
    private init() {
        checkAuthorizationStatus()
        
        // Refresh authorization status when app comes to foreground
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkAuthorizationStatus()
            }
        }
    }
    
    deinit {
        // Cancel task directly - Task cancellation is thread-safe
        periodicSyncTask?.cancel()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            isAuthorized = false
            return
        }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let heartType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        let stepStatus = healthStore.authorizationStatus(for: stepType)
        let caloriesStatus = healthStore.authorizationStatus(for: caloriesType)
        let heartStatus = healthStore.authorizationStatus(for: heartType)
        
        isAuthorized = (stepStatus == .sharingAuthorized)
            && (caloriesStatus == .sharingAuthorized)
            && (heartStatus == .sharingAuthorized)
    }
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: .distanceCycling)!,
            HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMass)!,
            HKQuantityType.quantityType(forIdentifier: .bodyMassIndex)!,
            HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)!,
            HKQuantityType.quantityType(forIdentifier: .bodyTemperature)!,
            HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKCategoryType.categoryType(forIdentifier: .mindfulSession)!
        ]
        
        let typesToWrite: Set<HKSampleType> = [
            HKQuantityType.quantityType(forIdentifier: .stepCount)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        
        checkAuthorizationStatus()
        
        // Read data immediately after authorization
        if isAuthorized {
            await readTodayData()
        }
    }
    
    // MARK: - Data Reading
    
    func readTodayData() async {
        await readTodaySteps()
        await readTodayActiveCalories()
        await readTodayRestingCalories()
        await readTodayWalkingRunningDistance()
        await readTodayCyclingDistance()
        await readTodayFlightsClimbed()
        await readSleepHours()
        await readMindfulMinutes()
        await readHeartRate()
        await readRestingHeartRate()
        await readHeartRateVariability()
        await readBloodOxygen()
        await readRespiratoryRate()
        await readBodyWeight()
        await readBodyMassIndex()
        await readBodyFatPercentage()
        await readBodyTemperature()
        await readBloodPressure()
    }

    private func todayPredicate() -> NSPredicate {
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        return HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
    }

    private func readCumulativeQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        onValue: @escaping @MainActor (Double) -> Void
    ) async {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        let query = HKStatisticsQuery(
            quantityType: quantityType,
            quantitySamplePredicate: todayPredicate(),
            options: .cumulativeSum
        ) { _, result, _ in
            let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
            Task { @MainActor in
                onValue(value)
            }
        }
        healthStore.execute(query)
    }

    private func readLatestQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        onValue: @escaping @MainActor (Double) -> Void
    ) async {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            let sample = samples?.first as? HKQuantitySample
            let value = sample?.quantity.doubleValue(for: unit) ?? 0
            Task { @MainActor in
                onValue(value)
            }
        }
        healthStore.execute(query)
    }

    private func readAverageTodayQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        onValue: @escaping @MainActor (Double) -> Void
    ) async {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return }
        let query = HKStatisticsQuery(
            quantityType: quantityType,
            quantitySamplePredicate: todayPredicate(),
            options: .discreteAverage
        ) { _, result, _ in
            let value = result?.averageQuantity()?.doubleValue(for: unit) ?? 0
            Task { @MainActor in
                onValue(value)
            }
        }
        healthStore.execute(query)
    }
    
    private func readTodaySteps() async {
        await readCumulativeQuantity(.stepCount, unit: .count()) { [weak self] value in
            guard let self = self else { return }
            let steps = Int(value)
            LocalDailyLogStore.shared.updateSteps(steps)
            self.todaySteps = steps
        }
    }
    
    private func readTodayActiveCalories() async {
        await readCumulativeQuantity(.activeEnergyBurned, unit: .kilocalorie()) { [weak self] calories in
            guard let self = self else { return }
            LocalDailyLogStore.shared.updateCaloriesBurned(calories)
            self.todayActiveCalories = calories
        }
    }

    private func readTodayRestingCalories() async {
        await readCumulativeQuantity(.basalEnergyBurned, unit: .kilocalorie()) { [weak self] value in
            self?.todayRestingCalories = value
        }
    }

    private func readTodayWalkingRunningDistance() async {
        await readCumulativeQuantity(.distanceWalkingRunning, unit: .meter()) { [weak self] value in
            self?.todayWalkingRunningDistance = value / 1000.0
        }
    }

    private func readTodayCyclingDistance() async {
        await readCumulativeQuantity(.distanceCycling, unit: .meter()) { [weak self] value in
            self?.todayCyclingDistance = value / 1000.0
        }
    }

    private func readTodayFlightsClimbed() async {
        await readCumulativeQuantity(.flightsClimbed, unit: .count()) { [weak self] value in
            self?.todayFlightsClimbed = Int(value)
        }
    }

    private func readSleepHours() async {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let now = Date()
        let sleepWindowStart = Calendar.current.date(byAdding: .hour, value: -24, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: sleepWindowStart, end: now, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
            guard let self = self else { return }
            let categorySamples = (samples as? [HKCategorySample]) ?? []
            let totalSeconds = categorySamples
                .filter { $0.value != HKCategoryValueSleepAnalysis.inBed.rawValue }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

            Task { @MainActor in
                self.sleepHours = totalSeconds / 3600.0
            }
        }
        healthStore.execute(query)
    }

    private func readMindfulMinutes() async {
        guard let mindfulType = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return }
        let query = HKSampleQuery(sampleType: mindfulType, predicate: todayPredicate(), limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
            guard let self = self else { return }
            let sessions = (samples as? [HKCategorySample]) ?? []
            let totalMinutes = sessions.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 60.0 }
            Task { @MainActor in
                self.mindfulMinutes = totalMinutes
            }
        }
        healthStore.execute(query)
    }
    
    private func readHeartRate() async {
        await readLatestQuantity(.heartRate, unit: HKUnit(from: "count/min")) { [weak self] value in
            self?.averageHeartRate = value
        }
    }

    private func readRestingHeartRate() async {
        await readLatestQuantity(.restingHeartRate, unit: HKUnit(from: "count/min")) { [weak self] value in
            self?.restingHeartRate = value
        }
    }

    private func readHeartRateVariability() async {
        await readLatestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli)) { [weak self] value in
            self?.heartRateVariability = value
        }
    }

    private func readBloodOxygen() async {
        await readLatestQuantity(.oxygenSaturation, unit: .percent()) { [weak self] value in
            self?.bloodOxygen = value * 100.0
        }
    }

    private func readRespiratoryRate() async {
        await readLatestQuantity(.respiratoryRate, unit: HKUnit(from: "count/min")) { [weak self] value in
            self?.respiratoryRate = value
        }
    }

    private func readBodyWeight() async {
        await readLatestQuantity(.bodyMass, unit: .gramUnit(with: .kilo)) { [weak self] value in
            self?.bodyWeightKg = value
        }
    }

    private func readBodyMassIndex() async {
        await readLatestQuantity(.bodyMassIndex, unit: .count()) { [weak self] value in
            self?.bodyMassIndex = value
        }
    }

    private func readBodyFatPercentage() async {
        await readLatestQuantity(.bodyFatPercentage, unit: .percent()) { [weak self] value in
            self?.bodyFatPercentage = value * 100.0
        }
    }

    private func readBodyTemperature() async {
        await readLatestQuantity(.bodyTemperature, unit: .degreeCelsius()) { [weak self] value in
            self?.bodyTemperatureCelsius = value
        }
    }

    private func readBloodPressure() async {
        await readLatestQuantity(.bloodPressureSystolic, unit: .millimeterOfMercury()) { [weak self] value in
            self?.systolicBloodPressure = value
        }
        await readLatestQuantity(.bloodPressureDiastolic, unit: .millimeterOfMercury()) { [weak self] value in
            self?.diastolicBloodPressure = value
        }
    }
    
    // MARK: - Backend Sync
    
    func syncToBackend() async throws {
        guard isAuthorized else {
            throw HealthKitError.notAuthorized
        }
        
        guard let token = AuthService.shared.readToken()?.accessToken else {
            throw HealthKitError.notAuthenticated
        }
        
        let url = URL(string: "\(NetworkManager.shared.baseURL)/health/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = [
            "steps": todaySteps,
            "activeCalories": todayActiveCalories,
            "restingCalories": todayRestingCalories,
            "walkingRunningDistanceKm": todayWalkingRunningDistance,
            "cyclingDistanceKm": todayCyclingDistance,
            "flightsClimbed": todayFlightsClimbed,
            "sleepHours": sleepHours,
            "mindfulMinutes": mindfulMinutes,
            "averageHeartRate": averageHeartRate,
            "restingHeartRate": restingHeartRate,
            "hrvMs": heartRateVariability,
            "bloodOxygenPercent": bloodOxygen,
            "respiratoryRate": respiratoryRate,
            "bodyWeightKg": bodyWeightKg,
            "bmi": bodyMassIndex,
            "bodyFatPercent": bodyFatPercentage,
            "bodyTemperatureC": bodyTemperatureCelsius,
            "bloodPressureSystolic": systolicBloodPressure,
            "bloodPressureDiastolic": diastolicBloodPressure
        ]

        // Keep old key for backwards compatibility
        if restingHeartRate > 0 {
            body["heartRate"] = restingHeartRate
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw HealthKitError.syncFailed
        }
    }
    
    // MARK: - Periodic Sync
    
    func startPeriodicSync() {
        stopPeriodicSync()
        
        periodicSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000) // 15 minutes
                
                guard let self = self,
                      self.isAuthorized,
                      AuthService.shared.readToken() != nil else {
                    return
                }
                
                await self.readTodayData()
                try? await self.syncToBackend()
            }
        }
    }
    
    func stopPeriodicSync() {
        periodicSyncTask?.cancel()
        periodicSyncTask = nil
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case notAuthorized
    case notAuthenticated
    case syncFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit authorization not granted"
        case .notAuthenticated:
            return "User not authenticated"
        case .syncFailed:
            return "Failed to sync HealthKit data to backend"
        }
    }
}
