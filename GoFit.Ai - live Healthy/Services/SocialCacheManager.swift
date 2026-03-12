import Foundation
import Combine

/// Blazing-fast local cache for social data (friends, conversations, messages)
/// Loads from disk instantly on launch, then refreshes from network in background
final class SocialCacheManager: ObservableObject {
    static let shared = SocialCacheManager()
    
    @Published var cachedFriends: [Friend] = []
    @Published var cachedConversations: [ConversationSummary] = []
    @Published var cachedFriendRequests: [FriendRequest] = []
    @Published var isLoadedFromCache = false
    
    private let friendsCacheKey = "social_friends_cache"
    private let conversationsCacheKey = "social_conversations_cache"
    private let requestsCacheKey = "social_requests_cache"
    
    private let cacheDir: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("SocialCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    private let queue = DispatchQueue(label: "social.cache.queue", qos: .userInitiated)
    
    private init() {
        loadFromDisk()
    }
    
    // MARK: - Load from Disk (Instant)
    
    private func loadFromDisk() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let friends = self.loadCache([Friend].self, key: self.friendsCacheKey)
            let convos = self.loadCache([ConversationSummary].self, key: self.conversationsCacheKey)
            let requests = self.loadCache([FriendRequest].self, key: self.requestsCacheKey)
            
            DispatchQueue.main.async {
                self.cachedFriends = friends ?? []
                self.cachedConversations = convos ?? []
                self.cachedFriendRequests = requests ?? []
                self.isLoadedFromCache = true
                print("⚡️ SocialCache: Loaded \(self.cachedFriends.count) friends, \(self.cachedConversations.count) conversations from disk")
            }
        }
    }
    
    // MARK: - Save Friends
    
    func saveFriends(_ friends: [Friend]) {
        DispatchQueue.main.async {
            self.cachedFriends = friends
        }
        queue.async { [weak self] in
            guard let self = self else { return }
            self.saveCache(friends, key: self.friendsCacheKey)
        }
    }
    
    // MARK: - Save Conversations
    
    func saveConversations(_ conversations: [ConversationSummary]) {
        DispatchQueue.main.async {
            self.cachedConversations = conversations
        }
        queue.async { [weak self] in
            guard let self = self else { return }
            self.saveCache(conversations, key: self.conversationsCacheKey)
        }
    }
    
    // MARK: - Save Friend Requests
    
    func saveFriendRequests(_ requests: [FriendRequest]) {
        DispatchQueue.main.async {
            self.cachedFriendRequests = requests
        }
        queue.async { [weak self] in
            guard let self = self else { return }
            self.saveCache(requests, key: self.requestsCacheKey)
        }
    }
    
    // MARK: - Cache Messages for a Conversation
    
    func saveMessages(_ messages: [MessageItem], for friendId: String) {
        queue.async { [weak self] in
            self?.saveCache(messages, key: "messages_\(friendId)")
        }
    }
    
    func loadMessages(for friendId: String) -> [MessageItem]? {
        return queue.sync {
            return loadCache([MessageItem].self, key: "messages_\(friendId)")
        }
    }
    
    // MARK: - Generic Cache Operations
    
    private func saveCache<T: Encodable>(_ object: T, key: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(object)
            let url = cacheDir.appendingPathComponent("\(key).json")
            try data.write(to: url, options: .atomic)
        } catch {
            print("⚠️ SocialCache: Failed to save \(key): \(error)")
        }
    }
    
    private func loadCache<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let url = cacheDir.appendingPathComponent("\(key).json")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            print("⚠️ SocialCache: Failed to load \(key): \(error)")
            return nil
        }
    }
    
    // MARK: - Clear Cache
    
    func clearAll() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.cacheDir)
            try? FileManager.default.createDirectory(at: self.cacheDir, withIntermediateDirectories: true)
            DispatchQueue.main.async {
                self.cachedFriends = []
                self.cachedConversations = []
                self.cachedFriendRequests = []
            }
        }
    }
}
