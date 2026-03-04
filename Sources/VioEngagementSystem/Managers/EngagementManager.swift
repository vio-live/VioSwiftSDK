import Foundation
import Combine
import VioCore

/// Engagement Manager for handling polls and contests with broadcast context
/// Manages engagement data organized by broadcastId for context-aware filtering
@MainActor
public class EngagementManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = EngagementManager()
    
    // MARK: - Published Properties
    @Published public private(set) var pollsByBroadcast: [String: [Poll]] = [:]
    @Published public private(set) var contestsByBroadcast: [String: [Contest]] = [:]
    @Published public private(set) var pollResults: [String: PollResults] = [:]
    
    // Backward compatibility properties
    @available(*, deprecated, renamed: "pollsByBroadcast")
    public var pollsByMatch: [String: [Poll]] {
        get { pollsByBroadcast }
        set { pollsByBroadcast = newValue }
    }
    
    @available(*, deprecated, renamed: "contestsByBroadcast")
    public var contestsByMatch: [String: [Contest]] {
        get { contestsByBroadcast }
        set { contestsByBroadcast = newValue }
    }
    
    // MARK: - Private Properties
    private var participationRecord: Set<String> = []  // Track poll votes locally
    private var contestParticipation: Set<String> = []  // Track contest participation
    private var repository: EngagementRepositoryProtocol
    
    // MARK: - Initialization
    private init() {
        let config = VioConfiguration.shared
        let effectiveConfig = config.effectiveEngagementConfiguration
        
        if effectiveConfig.demoMode {
            self.repository = DemoEngagementRepository()
        } else {
            self.repository = BackendEngagementRepository()
        }
        
        registerWebSocketHandlers()
    }
    
    /// Bridge CampaignWebSocketManager → EngagementManager across module boundaries.
    /// Static handlers are set once; the WS manager calls them for every filtered event.
    private func registerWebSocketHandlers() {
        CampaignWebSocketManager.engagementPollHandler = { [weak self] pollData, broadcastId in
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let poll = try? decoder.decode(Poll.self, from: pollData) else {
                VioLogger.error("Failed to decode poll from WS data", component: "EngagementManager")
                return
            }
            Task { @MainActor in
                self?.addOrUpdatePoll(poll, broadcastId: broadcastId)
            }
        }
        
        CampaignWebSocketManager.engagementContestHandler = { [weak self] contestData, broadcastId in
            let jsonStr = String(data: contestData, encoding: .utf8) ?? "?"
            print("🔵 [EngagementManager] engagementContestHandler called broadcastId=\(broadcastId) json=\(jsonStr.prefix(200))")
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let contest = try? decoder.decode(Contest.self, from: contestData) else {
                print("🔴 [EngagementManager] Failed to decode contest. json=\(jsonStr.prefix(300))")
                return
            }
            print("🟢 [EngagementManager] Contest decoded: id=\(contest.id) broadcastId=\(contest.broadcastId)")
            Task { @MainActor in
                self?.addOrUpdateContest(contest, broadcastId: broadcastId)
            }
        }
        
        VioLogger.debug("WebSocket engagement handlers registered", component: "EngagementManager")
    }
    
    /// Reload repository if configuration changed (e.g., dynamic config updated)
    private func reloadRepositoryIfNeeded() {
        let config = VioConfiguration.shared
        let effectiveConfig = config.effectiveEngagementConfiguration
        
        // Check if we need to switch repositories
        let shouldUseDemo = effectiveConfig.demoMode
        let currentlyUsingDemo = repository is DemoEngagementRepository
        
        if shouldUseDemo != currentlyUsingDemo {
            if shouldUseDemo {
                self.repository = DemoEngagementRepository()
            } else {
                self.repository = BackendEngagementRepository()
            }
            VioLogger.debug("Switched engagement repository based on config change", component: "EngagementManager")
        }
    }
    
    // MARK: - Public Methods
    
    /// Load engagement data (polls and contests) for a specific broadcast context
    /// - Parameters:
    ///   - context: Broadcast context for the engagement data
    ///   - limit: Optional limit for pagination
    ///   - offset: Optional offset for pagination
    ///   - useBackend: When true, use BackendEngagementRepository for this call even if demoMode is enabled (contentId flow)
    public func loadEngagement(for context: BroadcastContext, limit: Int? = nil, offset: Int? = nil, useBackend: Bool? = nil) async {
        VioLogger.debug("Loading engagement for broadcastId: \(context.broadcastId)", component: "EngagementManager")
        
        // When useBackend is true (contentId flow), temporarily use BackendEngagementRepository
        let effectiveRepository: EngagementRepositoryProtocol
        if useBackend == true {
            effectiveRepository = BackendEngagementRepository()
        } else {
            effectiveRepository = repository
        }
        
        // Set broadcast start time in VideoSyncManager if available in BroadcastContext
        if let startTimeString = context.startTime {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let broadcastStartTime = formatter.date(from: startTimeString) {
                VideoSyncManager.shared.setBroadcastStartTime(broadcastStartTime, for: context.broadcastId)
            } else {
                // Try without fractional seconds
                let simpleFormatter = ISO8601DateFormatter()
                if let broadcastStartTime = simpleFormatter.date(from: startTimeString) {
                    VideoSyncManager.shared.setBroadcastStartTime(broadcastStartTime, for: context.broadcastId)
                }
            }
        }
        
        // Try to load dynamic engagement config for this broadcast
        if let engagementConfig = await DynamicConfigurationManager.shared.loadEngagementConfig(broadcastId: context.broadcastId) {
            VioConfiguration.shared.updateDynamicEngagementConfig(engagementConfig)
            reloadRepositoryIfNeeded()
        }
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadPolls(for: context, limit: limit, offset: offset, repository: effectiveRepository)
            }
            group.addTask {
                await self.loadContests(for: context, limit: limit, offset: offset, repository: effectiveRepository)
            }
        }
    }
    
    /// Get active polls for a specific broadcast context
    /// Uses VideoSyncManager to filter polls based on video playback time
    public func getActivePolls(for context: BroadcastContext) -> [Poll] {
        let polls = pollsByBroadcast[context.broadcastId] ?? []
        return VideoSyncManager.shared.getActivePolls(polls, videoTime: nil)
    }
    
    /// Get active contests for a specific broadcast context
    /// Uses VideoSyncManager to filter contests based on video playback time
    public func getActiveContests(for context: BroadcastContext) -> [Contest] {
        let contests = contestsByBroadcast[context.broadcastId] ?? []
        return VideoSyncManager.shared.getActiveContests(contests, videoTime: nil)
    }
    
    // Note: MatchContext is a typealias of BroadcastContext, so the methods above automatically work for MatchContext
    
    /// Check if user has voted in a poll
    public func hasVotedInPoll(_ pollId: String) -> Bool {
        return participationRecord.contains(pollId)
    }
    
    /// Check if user has participated in a contest
    public func hasParticipatedInContest(_ contestId: String) -> Bool {
        return contestParticipation.contains(contestId)
    }
    
    /// Vote in a poll (with context validation)
    public func voteInPoll(
        pollId: String,
        optionId: String,
        broadcastContext: BroadcastContext,
        userId: String? = nil
    ) async throws {
        // Verify that the poll belongs to the correct context
        guard let poll = pollsByBroadcast[broadcastContext.broadcastId]?.first(where: { $0.id == pollId }) else {
            throw EngagementError.pollNotFound
        }
        
        // Verify that the poll is still active using VideoSyncManager
        if !VideoSyncManager.shared.isPollActive(poll, videoTime: nil) {
            throw EngagementError.pollClosed
        }
        
        // Verify that the user hasn't already voted
        if hasVotedInPoll(pollId) {
            throw EngagementError.alreadyVoted
        }
        
        // Send vote via repository (backend or demo)
        try await repository.voteInPoll(pollId: pollId, optionId: optionId, broadcastContext: broadcastContext, userId: userId)
        
        // Register participation locally
        participationRecord.insert(pollId)
        
        // Optimistic update - increment vote count locally
        updatePollResultsOptimistically(pollId: pollId, optionId: optionId)
    }
    
    /// Participate in a contest (with context validation)
    public func participateInContest(
        contestId: String,
        broadcastContext: BroadcastContext,
        answers: [String: String]? = nil,
        userId: String? = nil
    ) async throws {
        // Verify that the contest belongs to the correct context
        guard let contest = contestsByBroadcast[broadcastContext.broadcastId]?.first(where: { $0.id == contestId }) else {
            throw EngagementError.contestNotFound
        }
        
        // Send participation via repository (backend or demo)
        try await repository.participateInContest(
            contestId: contestId,
            broadcastContext: broadcastContext,
            answers: answers,
            userId: userId
        )
        
        // Register participation locally
        contestParticipation.insert(contestId)
    }
    
    // Note: MatchContext is a typealias of BroadcastContext, so the methods above automatically work for MatchContext
    
    // MARK: - WebSocket-driven engagement (Trello #161)
    
    /// Insert or replace a poll received via WebSocket for a given broadcast.
    public func addOrUpdatePoll(_ poll: Poll, broadcastId: String) {
        var polls = pollsByBroadcast[broadcastId] ?? []
        if let idx = polls.firstIndex(where: { $0.id == poll.id }) {
            polls[idx] = poll
        } else {
            polls.append(poll)
        }
        pollsByBroadcast[broadcastId] = polls
        VioLogger.debug("addOrUpdatePoll: \(poll.id) for broadcast \(broadcastId) — total \(polls.count)", component: "EngagementManager")
    }
    
    /// Insert or replace a contest received via WebSocket for a given broadcast.
    public func addOrUpdateContest(_ contest: Contest, broadcastId: String) {
        var contests = contestsByBroadcast[broadcastId] ?? []
        if let idx = contests.firstIndex(where: { $0.id == contest.id }) {
            contests[idx] = contest
        } else {
            contests.append(contest)
        }
        contestsByBroadcast[broadcastId] = contests
        VioLogger.debug("addOrUpdateContest: \(contest.id) for broadcast \(broadcastId) — total \(contests.count)", component: "EngagementManager")
    }
    
    /// Update poll results from WebSocket event
    public func updatePollResults(pollId: String, results: PollResults) {
        pollResults[pollId] = results
        VioLogger.debug("Updated results for poll: \(pollId)", component: "EngagementManager")
    }
    
    // MARK: - Private Methods
    
    private func loadPolls(for context: BroadcastContext, limit: Int?, offset: Int?, repository: EngagementRepositoryProtocol? = nil) async {
        let repo = repository ?? self.repository
        let polls = await repo.loadPolls(for: context, limit: limit, offset: offset)
        pollsByBroadcast[context.broadcastId] = polls
        
        // Set broadcastStartTime in VideoSyncManager from polls if available
        if let firstPoll = polls.first(where: { $0.broadcastStartTime != nil }),
           let broadcastStartTime = firstPoll.broadcastStartTime {
            VideoSyncManager.shared.setBroadcastStartTime(broadcastStartTime, for: context.broadcastId)
        }
        
        VioLogger.debug("Loaded \(polls.count) polls for broadcastId: \(context.broadcastId)", component: "EngagementManager")
    }
    
    private func loadContests(for context: BroadcastContext, limit: Int?, offset: Int?, repository: EngagementRepositoryProtocol? = nil) async {
        let repo = repository ?? self.repository
        let contests = await repo.loadContests(for: context, limit: limit, offset: offset)
        contestsByBroadcast[context.broadcastId] = contests
        
        // Set broadcastStartTime in VideoSyncManager from contests if available
        if let firstContest = contests.first(where: { $0.broadcastStartTime != nil }),
           let broadcastStartTime = firstContest.broadcastStartTime {
            VideoSyncManager.shared.setBroadcastStartTime(broadcastStartTime, for: context.broadcastId)
        }
        
        VioLogger.debug("Loaded \(contests.count) contests for broadcastId: \(context.broadcastId)", component: "EngagementManager")
    }
    
    private func updatePollResultsOptimistically(pollId: String, optionId: String) {
        // Optimistic update - increment vote count locally
        // Real results will come from WebSocket update
        guard var existingResults = pollResults[pollId] else {
            return
        }
        
        guard let optionIndex = existingResults.options.firstIndex(where: { $0.optionId == optionId }) else {
            return
        }
        
        // Create new option results with updated vote count
        var updatedOptions = existingResults.options
        let oldVoteCount = updatedOptions[optionIndex].voteCount
        let newVoteCount = oldVoteCount + 1
        let newTotalVotes = existingResults.totalVotes + 1
        
        // Update the option at the found index
        updatedOptions[optionIndex] = PollResults.PollOptionResults(
            optionId: updatedOptions[optionIndex].optionId,
            voteCount: newVoteCount,
            percentage: Double(newVoteCount) / Double(newTotalVotes) * 100.0
        )
        
        // Recalculate percentages for all options
        let recalculatedOptions = updatedOptions.map { option in
            PollResults.PollOptionResults(
                optionId: option.optionId,
                voteCount: option.voteCount,
                percentage: Double(option.voteCount) / Double(newTotalVotes) * 100.0
            )
        }
        
        // Create new results with updated data
        let updatedResults = PollResults(
            pollId: existingResults.pollId,
            totalVotes: newTotalVotes,
            options: recalculatedOptions
        )
        
        pollResults[pollId] = updatedResults
    }

}

// MARK: - Poll Results Model

public struct PollResults: Codable {
    public let pollId: String
    public let totalVotes: Int
    public let options: [PollOptionResults]
    
    public struct PollOptionResults: Codable {
        public let optionId: String
        public let voteCount: Int
        public let percentage: Double
    }
}

// MARK: - Engagement Errors

public enum EngagementError: LocalizedError {
    case pollNotFound
    case contestNotFound
    case pollClosed
    case alreadyVoted
    case voteFailed(statusCode: Int, message: String?)
    case participationFailed(statusCode: Int, message: String?)
    case networkError(URLError)
    case decodingError(DecodingError)
    case invalidURL
    case rateLimited(retryAfter: Int?)
    case httpError(statusCode: Int, message: String?)
    case invalidData([String])
    case broadcastNotFound(broadcastId: String)
    
    public var errorDescription: String? {
        switch self {
        case .pollNotFound:
            return "Poll not found for this broadcast"
        case .contestNotFound:
            return "Contest not found for this broadcast"
        case .pollClosed:
            return "Poll is no longer active"
        case .alreadyVoted:
            return "You have already voted in this poll"
        case .voteFailed(let statusCode, let message):
            return "Failed to submit vote (HTTP \(statusCode)): \(message ?? "Unknown error")"
        case .participationFailed(let statusCode, let message):
            return "Failed to participate in contest (HTTP \(statusCode)): \(message ?? "Unknown error")"
        case .networkError(let urlError):
            return "Network error: \(urlError.localizedDescription)"
        case .decodingError(let decodingError):
            return "Failed to decode response: \(decodingError.localizedDescription)"
        case .invalidURL:
            return "Invalid URL"
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(retryAfter ?? 60) seconds"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message ?? "Unknown error")"
        case .invalidData(let errors):
            return "Invalid data: \(errors.joined(separator: ", "))"
        case .broadcastNotFound(let broadcastId):
            return "Broadcast not found: \(broadcastId)"
        }
    }
}
