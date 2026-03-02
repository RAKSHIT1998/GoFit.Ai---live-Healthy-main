//
//  NearbyFitnessService.swift
//  GoFit.Ai - live Healthy
//
//  Location-based fitness people discovery (20km radius)
//  and competition matchmaking
//

import SwiftUI
import CoreLocation
import Combine

// MARK: - Nearby Person Model
struct NearbyPerson: Identifiable, Codable {
    let id: String
    let username: String
    let fullName: String?
    let profileImageUrl: String?
    let distance: Double // km
    let level: Int
    let currentStreak: Int
    let totalPoints: Int
    let favoriteWorkout: String?
    let bio: String?
    let age: Int?
    
    var displayName: String {
        fullName ?? username
    }
    
    var distanceText: String {
        if distance < 1 {
            return String(format: "%.0f m away", distance * 1000)
        }
        return String(format: "%.1f km away", distance)
    }
    
    var levelTitle: String {
        switch level {
        case 1: return "Beginner"
        case 2...4: return "Enthusiast"
        case 5...9: return "Dedicated"
        case 10...19: return "Champion"
        case 20...49: return "Master"
        default: return "Legend"
        }
    }
}

// MARK: - Competition Challenge
struct FitnessChallenge: Identifiable, Codable {
    let id: String
    let type: ChallengeType
    let createdAt: Date
    let expiresAt: Date
    let challengerId: String
    let challengerName: String
    let challengedId: String?
    let challengedName: String?
    var status: ChallengeStatus
    var challengerScore: Int
    var challengedScore: Int
    
    enum ChallengeType: String, Codable, CaseIterable {
        case steps = "steps"
        case calories = "calories"
        case workouts = "workouts"
        case streak = "streak"
        
        var title: String {
            switch self {
            case .steps: return "Step Battle"
            case .calories: return "Calorie Burn"
            case .workouts: return "Workout War"
            case .streak: return "Streak Showdown"
            }
        }
        
        var icon: String {
            switch self {
            case .steps: return "figure.walk"
            case .calories: return "flame.fill"
            case .workouts: return "figure.run"
            case .streak: return "bolt.fill"
            }
        }
        
        var unit: String {
            switch self {
            case .steps: return "steps"
            case .calories: return "kcal"
            case .workouts: return "workouts"
            case .streak: return "days"
            }
        }
        
        var color: Color {
            switch self {
            case .steps: return Color(red: 0.2, green: 0.85, blue: 0.4)
            case .calories: return Color(red: 1.0, green: 0.5, blue: 0.0)
            case .workouts: return Color(red: 0.4, green: 0.6, blue: 1.0)
            case .streak: return Color(red: 1.0, green: 0.84, blue: 0.0)
            }
        }
    }
    
    enum ChallengeStatus: String, Codable {
        case pending
        case active
        case completed
        case declined
    }
}

// MARK: - Swipe Action
enum SwipeAction {
    case challenge
    case skip
    case superLike
}

// MARK: - Nearby Fitness Service
@MainActor
final class NearbyFitnessService: ObservableObject {
    static let shared = NearbyFitnessService()
    
    @Published var nearbyPeople: [NearbyPerson] = []
    @Published var matchQueue: [NearbyPerson] = [] // For swiping
    @Published var activeChallenges: [FitnessChallenge] = []
    @Published var isLoading = false
    @Published var locationPermissionDenied = false
    @Published var userLocation: CLLocation?
    
    private let locationManager = CLLocationManager()
    private let locationDelegate = LocationDelegate()
    private let radiusKm: Double = 20.0
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupLocationManager()
        loadCachedData()
    }
    
    // MARK: - Location Setup
    private func setupLocationManager() {
        locationManager.delegate = locationDelegate
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 500 // Update every 500m
        
        locationDelegate.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                self?.userLocation = location
                await self?.fetchNearbyPeople()
            }
        }
        
        locationDelegate.onPermissionChange = { [weak self] authorized in
            Task { @MainActor in
                self?.locationPermissionDenied = !authorized
                if authorized {
                    self?.locationManager.startUpdatingLocation()
                }
            }
        }
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startDiscovery() {
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else if status == .notDetermined {
            requestLocationPermission()
        } else {
            locationPermissionDenied = true
        }
    }
    
    // MARK: - Fetch Nearby People
    func fetchNearbyPeople() async {
        guard let location = userLocation else { return }
        isLoading = true
        
        // Simulate API call with mock data for nearby people
        // In production, this would hit the backend with lat/lng
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        
        do {
            guard let token = UserDefaults.standard.string(forKey: "auth_token") else {
                isLoading = false
                return
            }
            
            let urlString = "\(AppConstants.apiBaseURL)/api/users/nearby?lat=\(lat)&lng=\(lng)&radius=\(radiusKm)"
            guard let url = URL(string: urlString) else {
                loadMockData(location: location)
                isLoading = false
                return
            }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let decoded = try JSONDecoder().decode([NearbyPerson].self, from: data)
                nearbyPeople = decoded.filter { $0.distance <= radiusKm }
                matchQueue = nearbyPeople.shuffled()
            } else {
                loadMockData(location: location)
            }
        } catch {
            loadMockData(location: location)
        }
        
        isLoading = false
    }
    
    // MARK: - Challenge Actions
    func sendChallenge(to person: NearbyPerson, type: FitnessChallenge.ChallengeType) {
        let challenge = FitnessChallenge(
            id: UUID().uuidString,
            type: type,
            createdAt: Date(),
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
            challengerId: UserDefaults.standard.string(forKey: "user_id") ?? "",
            challengerName: UserDefaults.standard.string(forKey: "user_name") ?? "You",
            challengedId: person.id,
            challengedName: person.displayName,
            status: .pending,
            challengerScore: 0,
            challengedScore: 0
        )
        activeChallenges.insert(challenge, at: 0)
        saveCachedData()
        HapticManager.shared.success()
    }
    
    func swipeAction(_ action: SwipeAction, person: NearbyPerson) {
        matchQueue.removeAll { $0.id == person.id }
        
        switch action {
        case .challenge:
            // Pick a random challenge type
            let types = FitnessChallenge.ChallengeType.allCases
            let randomType = types.randomElement() ?? .steps
            sendChallenge(to: person, type: randomType)
        case .superLike:
            sendChallenge(to: person, type: .steps)
        case .skip:
            break
        }
    }
    
    // MARK: - Mock Data (until backend supports nearby)
    private func loadMockData(location: CLLocation) {
        let workouts = ["Running", "Weight Lifting", "HIIT", "Yoga", "CrossFit", "Swimming", "Cycling", "Boxing", "Calisthenics"]
        let names = [
            ("Alex", "Alex Rivera"), ("Jordan", "Jordan Lee"), ("Sam", "Sam Chen"),
            ("Riley", "Riley Patel"), ("Morgan", "Morgan Kim"), ("Casey", "Casey Johnson"),
            ("Drew", "Drew Williams"), ("Jamie", "Jamie Taylor"), ("Avery", "Avery Brown"),
            ("Quinn", "Quinn Davis"), ("Sage", "Sage Anderson"), ("Phoenix", "Phoenix Martinez")
        ]
        let bios = [
            "Gym rat 🏋️ | 5AM club", "Running is my therapy 🏃‍♂️",
            "HIIT addict | Always pushing limits", "Yoga + weights = balance 🧘",
            "Former couch potato → now marathon runner", "Just trying to be 1% better every day",
            "CrossFit enthusiast | Box jumps > everything", "If it doesn't challenge you, it doesn't change you",
            "Fitness is a lifestyle, not a hobby", "Sweat now, shine later ✨",
            "Training for my first triathlon 🏊‍♂️🚴‍♂️🏃‍♂️", "Let's get after it 💪"
        ]
        
        nearbyPeople = names.enumerated().map { index, name in
            NearbyPerson(
                id: UUID().uuidString,
                username: name.0.lowercased(),
                fullName: name.1,
                profileImageUrl: nil,
                distance: Double.random(in: 0.5...19.5),
                level: Int.random(in: 1...25),
                currentStreak: Int.random(in: 0...60),
                totalPoints: Int.random(in: 100...10000),
                favoriteWorkout: workouts.randomElement(),
                bio: bios[index % bios.count],
                age: Int.random(in: 18...45)
            )
        }.sorted { $0.distance < $1.distance }
        
        matchQueue = nearbyPeople.shuffled()
    }
    
    // MARK: - Persistence
    private func loadCachedData() {
        if let data = UserDefaults.standard.data(forKey: "active_challenges"),
           let decoded = try? JSONDecoder().decode([FitnessChallenge].self, from: data) {
            activeChallenges = decoded
        }
    }
    
    private func saveCachedData() {
        if let data = try? JSONEncoder().encode(activeChallenges) {
            UserDefaults.standard.set(data, forKey: "active_challenges")
        }
    }
}

// MARK: - Location Delegate
class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onPermissionChange: ((Bool) -> Void)?
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onLocationUpdate?(location)
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let authorized = status == .authorizedWhenInUse || status == .authorizedAlways
        onPermissionChange?(authorized)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
