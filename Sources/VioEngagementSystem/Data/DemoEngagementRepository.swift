import Foundation
import VioCore

/// Demo implementation of EngagementRepositoryProtocol
/// Uses mock data from timeline events instead of backend API
public struct DemoEngagementRepository: EngagementRepositoryProtocol {
    
    /// Closure to provide timeline events for demo mode
    /// This should be set from the demo app to provide events from TimelineDataGenerator
    /// The closure receives events as [Any] and should return converted Poll and Contest arrays
    public static var timelineEventsProvider: (() -> [Any])? = nil
    
    /// Closure to convert poll events to Poll models
    /// Set from demo app to handle conversion of PollTimelineEvent to Poll
    public static var pollConverter: ((Any, BroadcastContext) -> Poll?)? = nil
    
    /// Closure to convert contest events to Contest models
    /// Set from demo app to handle conversion of CastingContestEvent to Contest
    public static var contestConverter: ((Any, BroadcastContext) -> Contest?)? = nil
    
    public func loadPolls(for context: BroadcastContext, limit: Int? = nil, offset: Int? = nil) async -> [Poll] {
        guard let eventsProvider = Self.timelineEventsProvider,
              let converter = Self.pollConverter else {
            VioLogger.warning("No timeline events provider or poll converter configured for demo mode", component: "DemoEngagementRepository")
            return []
        }
        
        let events = eventsProvider()
        
        // Filter and convert poll events
        var polls = events
            .compactMap { event in converter(event, context) }
        
        // Apply pagination if provided (demo mode simulates pagination)
        if let offset = offset {
            let startIndex = min(offset, polls.count)
            polls = Array(polls[startIndex...])
        }
        if let limit = limit {
            polls = Array(polls.prefix(limit))
        }
        
        VioLogger.debug("Loaded \(polls.count) polls from demo timeline for broadcastId: \(context.broadcastId)", component: "DemoEngagementRepository")
        return polls
    }
    
    public func loadContests(for context: BroadcastContext, limit: Int? = nil, offset: Int? = nil) async -> [Contest] {
        guard let eventsProvider = Self.timelineEventsProvider,
              let converter = Self.contestConverter else {
            VioLogger.warning("No timeline events provider or contest converter configured for demo mode", component: "DemoEngagementRepository")
            return []
        }
        
        let events = eventsProvider()
        
        // Filter and convert contest events
        var contests = events
            .compactMap { event in converter(event, context) }
        
        // Apply pagination if provided (demo mode simulates pagination)
        if let offset = offset {
            let startIndex = min(offset, contests.count)
            contests = Array(contests[startIndex...])
        }
        if let limit = limit {
            contests = Array(contests.prefix(limit))
        }
        
        VioLogger.debug("Loaded \(contests.count) contests from demo timeline for broadcastId: \(context.broadcastId)", component: "DemoEngagementRepository")
        return contests
    }
    
    public func voteInPoll(
        pollId: String,
        optionId: String,
        broadcastContext: BroadcastContext,
        userId: String? = nil
    ) async throws {
        // In demo mode, voting is simulated locally
        // No backend call is made
        VioLogger.debug("Demo mode: Simulating vote for poll \(pollId), option \(optionId)", component: "DemoEngagementRepository")
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    public func participateInContest(
        contestId: String,
        broadcastContext: BroadcastContext,
        answers: [String: String]?,
        userId: String? = nil
    ) async throws {
        // In demo mode, participation is simulated locally
        // No backend call is made
        VioLogger.debug("Demo mode: Simulating participation in contest \(contestId)", component: "DemoEngagementRepository")
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
}
