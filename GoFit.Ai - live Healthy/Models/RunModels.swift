import Foundation

enum DistanceUnit: String, CaseIterable, Identifiable, Codable {
    case kilometers
    case miles

    var id: String { rawValue }

    var label: String {
        switch self {
        case .kilometers: return "km"
        case .miles: return "mi"
        }
    }

    var distanceRatio: Double {
        switch self {
        case .kilometers: return 0.001
        case .miles: return 0.000621371
        }
    }

    var paceLabel: String {
        switch self {
        case .kilometers: return "min/km"
        case .miles: return "min/mi"
        }
    }

    func convertDistance(meters: Double) -> Double {
        return meters * distanceRatio
    }

    func convertPace(secondsPerMeter: Double) -> Double {
        // seconds per km or mile
        return secondsPerMeter * (1 / distanceRatio)
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

    var distanceMiles: Double { distanceKm * 0.621371 }
    var paceMinPerMile: Double { paceMinPerKm / 0.621371 }

    var paceFormatted: String {
        let minutes = Int(paceMinPerKm)
        let seconds = Int((paceMinPerKm - Double(minutes)) * 60)
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func paceFormatted(for unit: DistanceUnit) -> String {
        let pace = unit == .kilometers ? paceMinPerKm : paceMinPerMile
        let minutes = Int(pace)
        let seconds = Int((pace - Double(minutes)) * 60)
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func distance(for unit: DistanceUnit) -> Double {
        unit == .kilometers ? distanceKm : distanceMiles
    }
}
