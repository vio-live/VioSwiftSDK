import Foundation
import Combine
import VioCore

/// Video Synchronization Manager
/// Handles synchronization of engagement events (polls, contests) with video playback time
/// Supports both live and recorded videos
@MainActor
public class VideoSyncManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = VideoSyncManager()
    
    // MARK: - Published Properties
    /// Current video playback time in seconds (relative to video start)
    @Published public private(set) var currentVideoTime: Int?
    
    /// Absolute timestamp of broadcast start time, indexed by broadcastId
    @Published public private(set) var broadcastStartTimeByBroadcast: [String: Date] = [:]
    
    // Backward compatibility property
    @available(*, deprecated, renamed: "broadcastStartTimeByBroadcast")
    public var matchStartTimeByMatch: [String: Date] {
        get { broadcastStartTimeByBroadcast }
        set { broadcastStartTimeByBroadcast = newValue }
    }
    
    // MARK: - Private Properties
    private var updateTimer: Timer?
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// Update the current video playback time
    /// Should be called periodically from the video player/casting manager
    /// - Parameter time: Current video time in seconds (relative to video start)
    public func updateVideoTime(_ time: Int) {
        currentVideoTime = time
    }
    
    /// Set the broadcast start time for a specific broadcast
    /// - Parameters:
    ///   - date: Absolute timestamp of broadcast start
    ///   - broadcastId: Broadcast identifier
    public func setBroadcastStartTime(_ date: Date, for broadcastId: String) {
        broadcastStartTimeByBroadcast[broadcastId] = date
        VioLogger.debug("Set broadcast start time for \(broadcastId): \(date)", component: "VideoSyncManager")
    }
    
    /// Get broadcast start time for a specific broadcast
    /// - Parameter broadcastId: Broadcast identifier
    /// - Returns: Broadcast start time if available
    public func getBroadcastStartTime(for broadcastId: String) -> Date? {
        return broadcastStartTimeByBroadcast[broadcastId]
    }
    
    /// Clear broadcast start time for a specific broadcast
    /// - Parameter broadcastId: Broadcast identifier
    public func clearBroadcastStartTime(for broadcastId: String) {
        broadcastStartTimeByBroadcast.removeValue(forKey: broadcastId)
    }
    
    // Backward compatibility methods
    @available(*, deprecated, renamed: "setBroadcastStartTime(_:for:)")
    public func setMatchStartTime(_ date: Date, for matchId: String) {
        setBroadcastStartTime(date, for: matchId)
    }
    
    @available(*, deprecated, renamed: "getBroadcastStartTime(for:)")
    public func getMatchStartTime(for matchId: String) -> Date? {
        return getBroadcastStartTime(for: matchId)
    }
    
    @available(*, deprecated, renamed: "clearBroadcastStartTime(for:)")
    public func clearMatchStartTime(for matchId: String) {
        clearBroadcastStartTime(for: matchId)
    }
    
    /// Check if a poll should be active based on current video time
    /// - Parameters:
    ///   - poll: Poll to check
    ///   - videoTime: Current video time in seconds (optional, uses currentVideoTime if nil)
    /// - Returns: True if poll should be shown
    public func isPollActive(_ poll: Poll, videoTime: Int?) -> Bool {
        guard poll.isActive else { return false }
        
        // If video sync timestamps are available, use them
        if let videoStartTime = poll.videoStartTime,
           let videoEndTime = poll.videoEndTime,
           let currentTime = videoTime {
            // Poll is active if current time is within the video time range
            return currentTime >= videoStartTime && currentTime < videoEndTime
        }
        
        // Fallback to absolute timestamps (backward compatibility)
        if let endTime = poll.endTime {
            let now = Date()
            return now < endTime
        }
        
        return poll.isActive
    }
    
    /// Check if a contest should be active based on current video time
    /// - Parameters:
    ///   - contest: Contest to check
    ///   - videoTime: Current video time in seconds (optional, uses currentVideoTime if nil)
    /// - Returns: True if contest should be shown
    public func isContestActive(_ contest: Contest, videoTime: Int?) -> Bool {
        guard contest.isActive else { return false }
        
        // If video sync timestamps are available, use them
        if let videoStartTime = contest.videoStartTime,
           let videoEndTime = contest.videoEndTime,
           let currentTime = videoTime {
            // Contest is active if current time is within the video time range
            return currentTime >= videoStartTime && currentTime < videoEndTime
        }
        
        // Fallback to absolute timestamps (backward compatibility)
        if let endTime = contest.endTime {
            let now = Date()
            return now < endTime
        }
        
        return contest.isActive
    }
    
    /// Filter polls that should be active based on current video time
    /// - Parameters:
    ///   - polls: Array of polls to filter
    ///   - videoTime: Current video time in seconds (optional, uses currentVideoTime if nil)
    /// - Returns: Filtered array of active polls
    public func getActivePolls(_ polls: [Poll], videoTime: Int? = nil) -> [Poll] {
        let time = videoTime ?? currentVideoTime
        return polls.filter { isPollActive($0, videoTime: time) }
    }
    
    /// Filter contests that should be active based on current video time
    /// - Parameters:
    ///   - contests: Array of contests to filter
    ///   - videoTime: Current video time in seconds (optional, uses currentVideoTime if nil)
    /// - Returns: Filtered array of active contests
    public func getActiveContests(_ contests: [Contest], videoTime: Int? = nil) -> [Contest] {
        let time = videoTime ?? currentVideoTime
        return contests.filter { isContestActive($0, videoTime: time) }
    }
    
    /// Reset all synchronization data
    public func reset() {
        currentVideoTime = nil
        broadcastStartTimeByBroadcast.removeAll()
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}
