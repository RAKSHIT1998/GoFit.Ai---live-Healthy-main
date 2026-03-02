//
//  DataPrefetchManager.swift
//  GoFit.Ai - live Healthy
//
//  Manages data prefetching for faster app loading
//

import Foundation
import UIKit
import Combine

/// Manages background data prefetching to improve perceived app performance
class DataPrefetchManager {
    static let shared = DataPrefetchManager()
    
    private var cancellables = Set<AnyCancellable>()
    private var hasPrefetched = false
    
    // Cached data
    private(set) var cachedMealTotals: (calories: Double, protein: Double, carbs: Double, fat: Double, sugar: Double)?
    private(set) var cachedWaterIntake: Double?
    private(set) var cachedTargetCalories: Int?
    private(set) var lastPrefetchTime: Date?
    
    private init() {}
    
    /// Prefetch all common data in parallel
    func prefetchAllData() async {
        guard !hasPrefetched || shouldRefreshCache() else { return }
        
        async let mealData: Void = prefetchMealData()
        async let waterData: Void = prefetchWaterData()
        async let targetData: Void = prefetchTargetCalories()
        
        _ = await (mealData, waterData, targetData)
        
        hasPrefetched = true
        lastPrefetchTime = Date()
    }
    
    /// Check if cache should be refreshed (every 5 minutes)
    private func shouldRefreshCache() -> Bool {
        guard let lastTime = lastPrefetchTime else { return true }
        return Date().timeIntervalSince(lastTime) > 300 // 5 minutes
    }
    
    /// Prefetch meal totals from local cache
    private func prefetchMealData() async {
        let totals = LocalMealCache.shared.getTodayTotals()
        cachedMealTotals = totals
    }
    
    /// Prefetch water intake data
    private func prefetchWaterData() async {
        guard let token = AuthService.shared.readToken()?.accessToken else { return }
        
        do {
            let url = URL(string: "\(AppConstants.baseURL)/api/liquid-log/today")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 5
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let todayIntake = json["todayIntake"] as? Double {
                cachedWaterIntake = todayIntake
            }
        } catch {
            print("Prefetch water data error: \(error)")
        }
    }
    
    /// Prefetch target calories from user profile
    private func prefetchTargetCalories() async {
        guard let token = AuthService.shared.readToken()?.accessToken else { return }
        
        do {
            let url = URL(string: "\(AppConstants.baseURL)/api/user/profile")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 5
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let user = json["user"] as? [String: Any],
                   let target = user["targetCalories"] as? Int {
                    cachedTargetCalories = target
                } else if let target = json["targetCalories"] as? Int {
                    cachedTargetCalories = target
                }
            }
        } catch {
            print("Prefetch target calories error: \(error)")
        }
    }
    
    /// Invalidate cache to force refresh
    func invalidateCache() {
        hasPrefetched = false
        cachedMealTotals = nil
        cachedWaterIntake = nil
        cachedTargetCalories = nil
        lastPrefetchTime = nil
    }
    
    /// Get cached meal totals or fetch fresh
    func getMealTotals() -> (calories: Double, protein: Double, carbs: Double, fat: Double, sugar: Double) {
        if let cached = cachedMealTotals {
            return cached
        }
        return LocalMealCache.shared.getTodayTotals()
    }
}

// MARK: - Image Cache Manager
class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private init() {
        // Set up disk cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache")
        
        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Configure memory cache
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    /// Get image from cache (memory first, then disk)
    func getImage(forKey key: String) -> UIImage? {
        // Check memory cache
        if let image = cache.object(forKey: key as NSString) {
            return image
        }
        
        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Store in memory cache for faster access next time
            cache.setObject(image, forKey: key as NSString)
            return image
        }
        
        return nil
    }
    
    /// Store image in cache (memory and disk)
    func setImage(_ image: UIImage, forKey key: String) {
        // Memory cache
        cache.setObject(image, forKey: key as NSString)
        
        // Disk cache (background)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self,
                  let data = image.jpegData(compressionQuality: 0.8) else { return }
            
            let fileURL = self.cacheDirectory.appendingPathComponent(key.sha256())
            try? data.write(to: fileURL)
        }
    }
    
    /// Clear all cached images
    func clearCache() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - String SHA256 Extension
private extension String {
    func sha256() -> String {
        let data = Data(self.utf8)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

import CommonCrypto
