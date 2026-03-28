import Foundation

extension NetworkManager {
    /// Fetch analytics for a given period (daily, weekly, monthly, yearly)
    func fetchAnalytics(period: String = "weekly") async throws -> AnalyticsData {
        let path = "/analytics/calculate?period=\(period)"
        return try await request(path)
    }
    
    /// Fetch saved analytics history for a given period
    func fetchSavedAnalytics(period: String = "weekly", limit: Int = 10) async throws -> [AnalyticsData] {
        let path = "/analytics/saved?period=\(period)&limit=\(limit)"
        return try await request(path)
    }
}
