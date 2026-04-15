import Foundation

class FriendsService: NSObject, ObservableObject {
    static let shared = FriendsService()
    
    @Published var friends: [Friend] = []
    @Published var friendRequests: [FriendRequest] = []
    @Published var searchResults: [SearchResult] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let baseURL: String
    
    override init() {
        if let baseURL = UserDefaults.standard.string(forKey: "backendURL"), !baseURL.isEmpty {
            self.baseURL = baseURL
        } else {
            // Default to production Render backend
            self.baseURL = "https://gofit-ai-live-healthy-1.onrender.com"
        }
        super.init()
        
        // Load from local cache instantly
        let cache = SocialCacheManager.shared
        if !cache.cachedFriends.isEmpty {
            self.friends = cache.cachedFriends
        }
        if !cache.cachedFriendRequests.isEmpty {
            self.friendRequests = cache.cachedFriendRequests
        }
    }
    
    // MARK: - Friend Requests
    
    /// Send a friend request to another user
    func sendFriendRequest(to userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "\(baseURL)/api/friends/request/\(userId)"
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "No data", code: -1)
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(FriendResponse.self, from: data)
                    completion(.success(response.message))
                } catch {
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Fetch pending friend requests
    func fetchFriendRequests(completion: @escaping (Result<[FriendRequest], Error>) -> Void) {
        let endpoint = "\(baseURL)/api/friends/requests"
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "No data", code: -1)
                    completion(.failure(error))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(FriendRequestsResponse.self, from: data)
                    self?.friendRequests = response.requests
                    SocialCacheManager.shared.saveFriendRequests(response.requests)
                    completion(.success(response.requests))
                } catch {
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Accept a friend request
    func acceptFriendRequest(from friendId: String, completion: @escaping (Result<String, Error>) -> Void) {
        isLoading = true
        let endpoint = "\(baseURL)/api/friends/accept/\(friendId)"
        
        guard let url = URL(string: endpoint) else {
            isLoading = false
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.isLoading = false
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                do {
                    if let data = data {
                        let response = try JSONDecoder().decode(FriendResponse.self, from: data)
                        self?.friendRequests.removeAll { $0.id == friendId }
                        completion(.success(response.message))
                    }
                    self?.isLoading = false
                } catch {
                    self?.isLoading = false
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    /// Reject a friend request
    func rejectFriendRequest(from friendId: String, completion: @escaping (Result<String, Error>) -> Void) {
        isLoading = true
        let endpoint = "\(baseURL)/api/friends/reject/\(friendId)"
        
        guard let url = URL(string: endpoint) else {
            isLoading = false
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.isLoading = false
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                self?.friendRequests.removeAll { $0.id == friendId }
                self?.isLoading = false
                completion(.success("Friend request rejected"))
            }
        }.resume()
    }
    
    // MARK: - Friends List
    
    /// Fetch all accepted friends
    func fetchFriends(completion: @escaping (Result<[Friend], Error>) -> Void) {
        let endpoint = "\(baseURL)/api/friends"
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "No data", code: -1)
                    completion(.failure(error))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(FriendsListResponse.self, from: data)
                    self?.friends = response.friends
                    SocialCacheManager.shared.saveFriends(response.friends)
                    completion(.success(response.friends))
                } catch {
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }.resume()
        
        isLoading = true
    }
    
private let autoShareKey = "auto_share_body_logs_enabled"
    private let autoShareIntervalHoursKey = "auto_share_body_logs_interval_hours"
    private let lastAutoShareDateKey = "last_body_log_share_date"

    /// Remove a friend
    func removeFriend(friendId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "\(baseURL)/api/friends/\(friendId)"
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                self?.friends.removeAll { $0.id == friendId }
                completion(.success("Friend removed"))
            }
        }.resume()
    }
    
    // MARK: - Search Users
    
    /// Search for users by username or email
    func searchUsers(query: String, completion: @escaping (Result<[SearchResult], Error>) -> Void) {
        guard query.count >= 2 else {
            completion(.success([]))
            return
        }
        
        let endpoint = "\(baseURL)/api/friends/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=20"
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        isLoading = true
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    let error = NSError(domain: "No data", code: -1)
                    completion(.failure(error))
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(SearchUsersResponse.self, from: data)
                    self?.searchResults = response.results
                    completion(.success(response.results))
                } catch {
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Block/Unblock
    
    /// Block a user
    func blockUser(userId: String, completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "\(baseURL)/api/friends/block/\(userId)"
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = error.localizedDescription
                    completion(.failure(error))
                    return
                }
                
                completion(.success("User blocked"))
            }
        }.resume()
    }
    
    /// Get friend statistics
    func getFriendStats(friendId: String, completion: @escaping (Result<FriendStats, Error>) -> Void) {
        let endpoint = "\(baseURL)/api/friends/stats/\(friendId)"
        
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = AuthService.shared.readToken()?.accessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "No data", code: -1)))
                    return
                }
                
                do {
                    let decoder = JSONDecoder.socialDecoder()
                    let response = try decoder.decode(FriendStatsResponse.self, from: data)
                    completion(.success(response.stats))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    // MARK: - Auto Share Body Log
    func setAutoShareBodyLogEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: autoShareKey)
    }

    func isAutoShareBodyLogEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: autoShareKey)
    }

    func setAutoShareInterval(hours: Int) {
        UserDefaults.standard.set(hours, forKey: autoShareIntervalHoursKey)
    }

    func autoShareIntervalHours() -> Int {
        let value = UserDefaults.standard.integer(forKey: autoShareIntervalHoursKey)
        return value > 0 ? value : 24
    }

    private func canAutoShareNow() -> Bool {
        let interval = TimeInterval(autoShareIntervalHours() * 3600)
        guard let last = UserDefaults.standard.object(forKey: lastAutoShareDateKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(last) >= interval
    }

    func shareBodyLogEntryToAllFriends(_ entry: BodyLogEntry, completion: ((Result<Int, Error>) -> Void)? = nil) {
        guard isAutoShareBodyLogEnabled() else {
            completion?(.failure(NSError(domain: "Auto share disabled", code: -1)))
            return
        }

        guard canAutoShareNow() else {
            completion?(.failure(NSError(domain: "Too soon to share again", code: -1)))
            return
        }

        let friendsToShare = friends.isEmpty ? [] : friends
        guard !friendsToShare.isEmpty else {
            completion?(.failure(NSError(domain: "No friends to share with", code: -1)))
            return
        }

        let summary = "📷 Body log update: \(entry.formattedWeight) at \(entry.formattedDate)\n" +
            "📌 Note: \(entry.note ?? "No note")"

        var successCount = 0
        var lastError: Error?
        let group = DispatchGroup()

        for friend in friendsToShare {
            group.enter()
            MessagesService.shared.sendMessage(friendId: friend.id, message: summary) { result in
                switch result {
                case .success:
                    successCount += 1
                case .failure(let error):
                    lastError = error
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            UserDefaults.standard.set(Date(), forKey: self.lastAutoShareDateKey)
            if let error = lastError, successCount == 0 {
                completion?(.failure(error))
            } else {
                completion?(.success(successCount))
            }
        }
    }
}
