import Foundation
import VioCore

/// Protocol for engagement data repository
/// Abstracts data source (backend vs demo) for polls and contests
public protocol EngagementRepositoryProtocol {
    /// Load polls for a specific broadcast context
    func loadPolls(for context: BroadcastContext, limit: Int?, offset: Int?) async -> [Poll]
    
    /// Load contests for a specific broadcast context
    func loadContests(for context: BroadcastContext, limit: Int?, offset: Int?) async -> [Contest]
    
    /// Vote in a poll
    func voteInPoll(
        pollId: String,
        optionId: String,
        broadcastContext: BroadcastContext,
        userId: String?
    ) async throws
    
    /// Participate in a contest
    func participateInContest(
        contestId: String,
        broadcastContext: BroadcastContext,
        answers: [String: String]?,
        userId: String?
    ) async throws
}

// Note: MatchContext is a typealias of BroadcastContext, so the protocol methods automatically work for MatchContext
// No need for default implementations since MatchContext can be passed directly to methods expecting BroadcastContext
