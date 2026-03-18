import Foundation

// MARK: - Recommendation Cache Manager
/// Caches AI recommendations locally to avoid redundant OpenAI API calls.
/// Saves ~$0.02–$0.10 per avoided call (GPT-4o tokens are expensive).
///
/// Policy:
///   • Normal load → serve cached if < 6 hours old
///   • Force refresh → always hit API, but enforce 2-minute cooldown between refreshes
///   • Persisted to disk so cache survives app restarts
final class RecommendationCacheManager {
    static let shared = RecommendationCacheManager()
    
    private let fileManager = FileManager.default
    private let cacheFileName = "recommendation_cache.json"
    private let metaFileName = "recommendation_meta.json"
    
    /// How long cached recommendations are considered fresh (6 hours)
    private let cacheTTL: TimeInterval = 6 * 60 * 60
    
    /// Minimum interval between force-refresh API calls (2 minutes)
    private let refreshCooldown: TimeInterval = 2 * 60
    
    private var cacheFileURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(cacheFileName)
    }
    
    private var metaFileURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(metaFileName)
    }
    
    private init() {}
    
    // MARK: - Cache Metadata
    
    private struct CacheMeta: Codable {
        var lastFetchDate: Date
        var lastRefreshDate: Date?
    }
    
    private func loadMeta() -> CacheMeta? {
        guard let data = try? Data(contentsOf: metaFileURL) else { return nil }
        return try? JSONDecoder.withISO8601.decode(CacheMeta.self, from: data)
    }
    
    private func saveMeta(_ meta: CacheMeta) {
        if let data = try? JSONEncoder.withISO8601.encode(meta) {
            try? data.write(to: metaFileURL)
        }
    }
    
    // MARK: - Public API
    
    /// Returns cached recommendations if still fresh, otherwise nil.
    func loadCachedRecommendation() -> RecommendationResponse? {
        guard let meta = loadMeta() else { return nil }
        
        let age = Date().timeIntervalSince(meta.lastFetchDate)
        guard age < cacheTTL else {
            print("📦 Recommendation cache expired (\(Int(age/3600))h old)")
            return nil
        }
        
        guard let data = try? Data(contentsOf: cacheFileURL) else { return nil }
        guard let cached = try? JSONDecoder().decode(RecommendationResponse.self, from: data) else { return nil }
        
        print("📦 Serving cached recommendations (\(Int(age/60))m old, TTL: \(Int(cacheTTL/3600))h)")
        return cached
    }
    
    /// Save a fresh recommendation to cache.
    func cacheRecommendation(_ response: RecommendationResponse, wasRefresh: Bool = false) {
        if let data = try? JSONEncoder().encode(response) {
            try? data.write(to: cacheFileURL)
        }
        
        var meta = loadMeta() ?? CacheMeta(lastFetchDate: Date())
        meta.lastFetchDate = Date()
        if wasRefresh {
            meta.lastRefreshDate = Date()
        }
        saveMeta(meta)
        
        print("📦 Cached recommendations to disk")
    }
    
    /// Whether a force-refresh is allowed (cooldown check).
    var canRefresh: Bool {
        guard let meta = loadMeta(), let lastRefresh = meta.lastRefreshDate else {
            return true // Never refreshed before
        }
        let elapsed = Date().timeIntervalSince(lastRefresh)
        if elapsed < refreshCooldown {
            print("⏳ Refresh cooldown: wait \(Int(refreshCooldown - elapsed))s")
            return false
        }
        return true
    }
    
    /// Seconds remaining on the refresh cooldown, or 0 if ready.
    var refreshCooldownRemaining: Int {
        guard let meta = loadMeta(), let lastRefresh = meta.lastRefreshDate else { return 0 }
        let elapsed = Date().timeIntervalSince(lastRefresh)
        return max(0, Int(refreshCooldown - elapsed))
    }
    
    /// Clear the cache (e.g. on logout).
    func clearCache() {
        try? fileManager.removeItem(at: cacheFileURL)
        try? fileManager.removeItem(at: metaFileURL)
        print("📦 Recommendation cache cleared")
    }
}

// MARK: - JSON Coder helpers
private extension JSONDecoder {
    static let withISO8601: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

private extension JSONEncoder {
    static let withISO8601: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}
