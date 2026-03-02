//
//  BodyLogManager.swift
//  GoFit.Ai - live Healthy
//
//  Manages daily body weight + progress photo logs
//

import SwiftUI
import UIKit

// MARK: - Body Log Entry
struct BodyLogEntry: Codable, Identifiable {
    let id: String
    let date: Date
    let weight: Double // in kg
    let photoFilename: String? // local file reference
    let note: String?
    
    init(id: String = UUID().uuidString, date: Date = Date(), weight: Double, photoFilename: String? = nil, note: String? = nil) {
        self.id = id
        self.date = date
        self.weight = weight
        self.photoFilename = photoFilename
        self.note = note
    }
    
    var formattedWeight: String {
        String(format: "%.1f kg", weight)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Body Log Manager
@MainActor
final class BodyLogManager: ObservableObject {
    static let shared = BodyLogManager()
    
    @Published var entries: [BodyLogEntry] = []
    @Published var latestWeight: Double? = nil
    
    private let storageKey = "body_log_entries"
    private let photoDirectory = "body_photos"
    
    private init() {
        loadEntries()
    }
    
    // MARK: - CRUD
    func addEntry(weight: Double, photo: UIImage?, note: String?) {
        var photoFilename: String? = nil
        
        if let photo = photo, let data = photo.jpegData(compressionQuality: 0.7) {
            let filename = "body_\(UUID().uuidString).jpg"
            photoFilename = filename
            savePhotoToDisk(data: data, filename: filename)
        }
        
        let entry = BodyLogEntry(
            date: Date(),
            weight: weight,
            photoFilename: photoFilename,
            note: note
        )
        
        entries.insert(entry, at: 0)
        latestWeight = weight
        saveEntries()
        
        HapticManager.shared.success()
    }
    
    func deleteEntry(_ entry: BodyLogEntry) {
        if let filename = entry.photoFilename {
            deletePhotoFromDisk(filename: filename)
        }
        entries.removeAll { $0.id == entry.id }
        latestWeight = entries.first?.weight
        saveEntries()
    }
    
    func entriesForDate(_ date: Date) -> [BodyLogEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    func weightTrend(days: Int = 7) -> [(date: Date, weight: Double)] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return entries
            .filter { $0.date >= startDate }
            .sorted { $0.date < $1.date }
            .map { (date: $0.date, weight: $0.weight) }
    }
    
    var weeklyChange: Double? {
        let trend = weightTrend(days: 7)
        guard let first = trend.first?.weight, let last = trend.last?.weight, trend.count >= 2 else { return nil }
        return last - first
    }
    
    // MARK: - Photo Management
    func loadPhoto(filename: String) -> UIImage? {
        let url = getPhotoDirectory().appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    private func savePhotoToDisk(data: Data, filename: String) {
        let dir = getPhotoDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(filename)
        try? data.write(to: url)
    }
    
    private func deletePhotoFromDisk(filename: String) {
        let url = getPhotoDirectory().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
    
    private func getPhotoDirectory() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(photoDirectory)
    }
    
    // MARK: - Persistence
    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([BodyLogEntry].self, from: data) else { return }
        entries = decoded.sorted { $0.date > $1.date }
        latestWeight = entries.first?.weight
    }
    
    private func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
