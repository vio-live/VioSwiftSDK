import Foundation

/// Cache for engagement data (polls and contests) with TTL support
actor EngagementCache {
    
    // MARK: - Cache Entries
    
    private struct CachedPolls {
        let polls: [Poll]
        let timestamp: Date
        let ttl: TimeInterval
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) >= ttl
        }
    }
    
    private struct CachedContests {
        let contests: [Contest]
        let timestamp: Date
        let ttl: TimeInterval
        
        var isExpired: Bool {
            Date().timeIntervalSince(timestamp) >= ttl
        }
    }
    
    // MARK: - Properties
    
    private var pollsCache: [String: CachedPolls] = [:]
    private var contestsCache: [String: CachedContests] = [:]
    
    /// Default TTL for polls (60 seconds)
    private let defaultPollsTTL: TimeInterval = 60
    
    /// Default TTL for contests (120 seconds)
    private let defaultContestsTTL: TimeInterval = 120
    
    // MARK: - Public Methods
    
    /// Get cached polls for a broadcast
    /// Returns nil if cache is expired or doesn't exist
    func getCachedPolls(for broadcastId: String) -> [Poll]? {
        guard let cached = pollsCache[broadcastId],
              !cached.isExpired else {
            return nil
        }
        return cached.polls
    }
    
    /// Set cached polls for a broadcast
    func setCachedPolls(_ polls: [Poll], for broadcastId: String, ttl: TimeInterval? = nil) {
        let cacheTTL = ttl ?? defaultPollsTTL
        pollsCache[broadcastId] = CachedPolls(
            polls: polls,
            timestamp: Date(),
            ttl: cacheTTL
        )
    }
    
    /// Get cached contests for a broadcast
    /// Returns nil if cache is expired or doesn't exist
    func getCachedContests(for broadcastId: String) -> [Contest]? {
        guard let cached = contestsCache[broadcastId],
              !cached.isExpired else {
            return nil
        }
        return cached.contests
    }
    
    /// Set cached contests for a broadcast
    func setCachedContests(_ contests: [Contest], for broadcastId: String, ttl: TimeInterval? = nil) {
        let cacheTTL = ttl ?? defaultContestsTTL
        contestsCache[broadcastId] = CachedContests(
            contests: contests,
            timestamp: Date(),
            ttl: cacheTTL
        )
    }
    
    /// Invalidate cache for a specific broadcast
    func invalidateCache(for broadcastId: String) {
        pollsCache.removeValue(forKey: broadcastId)
        contestsCache.removeValue(forKey: broadcastId)
    }
    
    /// Clear all cached data
    func clearAll() {
        pollsCache.removeAll()
        contestsCache.removeAll()
    }
    
    /// Remove expired entries (cleanup)
    func cleanupExpired() {
        pollsCache = pollsCache.filter { !$0.value.isExpired }
        contestsCache = contestsCache.filter { !$0.value.isExpired }
    }
}
