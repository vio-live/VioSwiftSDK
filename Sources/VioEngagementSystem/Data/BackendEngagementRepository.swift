import Foundation
import VioCore

/// Backend implementation of EngagementRepositoryProtocol
/// Uses REST API to fetch polls and contests from the backend
/// Implements retry logic, caching, and improved error handling
struct BackendEngagementRepository: EngagementRepositoryProtocol {
    
    // MARK: - Dependencies
    
    private let networkClient: NetworkClient
    private let cache: EngagementCache
    private let retryHandler: RequestRetryHandler
    
    // MARK: - Configuration
    
    private var campaignRestAPIBaseURL: String {
        VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
    }
    
    private static let userIdStorageKey = "VioEngagement.UserId"
    
    // MARK: - Initialization
    
    init(
        networkClient: NetworkClient = URLSession.shared,
        cache: EngagementCache = EngagementCache(),
        retryHandler: RequestRetryHandler = RequestRetryHandler()
    ) {
        self.networkClient = networkClient
        self.cache = cache
        self.retryHandler = retryHandler
    }
    
    // MARK: - EngagementRepositoryProtocol Implementation
    
    func loadPolls(for context: BroadcastContext, limit: Int? = nil, offset: Int? = nil) async -> [Poll] {
        let startTime = Date()
        var retryCount = 0
        
        // Check cache first
        if let cachedPolls = await cache.getCachedPolls(for: context.broadcastId) {
            VioLogger.debug(
                "Returning cached polls for broadcastId: \(context.broadcastId)",
                component: "BackendEngagementRepository"
            )
            return cachedPolls
        }
        
        do {
            let polls = try await retryHandler.execute(
                operation: {
                    retryCount += 1
                    return try await self.fetchPollsFromBackend(for: context, limit: limit, offset: offset)
                },
                shouldRetry: { error, attempt in
                    self.shouldRetry(error: error, attempt: attempt)
                }
            )
            
            // Cache successful response
            await cache.setCachedPolls(polls, for: context.broadcastId)
            
            // Log metrics
            let metrics = EngagementRequestMetrics(
                endpoint: "/v1/engagement/polls",
                broadcastId: context.broadcastId,
                duration: Date().timeIntervalSince(startTime),
                statusCode: 200,
                error: nil,
                responseSize: nil,
                retryCount: retryCount
            )
            metrics.log()
            
            return polls
            
        } catch {
            // Log metrics with error
            let metrics = EngagementRequestMetrics(
                endpoint: "/v1/engagement/polls",
                broadcastId: context.broadcastId,
                duration: Date().timeIntervalSince(startTime),
                statusCode: nil,
                error: error,
                responseSize: nil,
                retryCount: retryCount
            )
            metrics.log()
            
            VioLogger.error(
                "Failed to load polls after \(retryCount) attempts: \(error)",
                component: "BackendEngagementRepository"
            )
            return []
        }
    }
    
    func loadContests(for context: BroadcastContext, limit: Int? = nil, offset: Int? = nil) async -> [Contest] {
        let startTime = Date()
        var retryCount = 0
        
        // Check cache first
        if let cachedContests = await cache.getCachedContests(for: context.broadcastId) {
            VioLogger.debug(
                "Returning cached contests for broadcastId: \(context.broadcastId)",
                component: "BackendEngagementRepository"
            )
            return cachedContests
        }
        
        do {
            let contests = try await retryHandler.execute(
                operation: {
                    retryCount += 1
                    return try await self.fetchContestsFromBackend(for: context, limit: limit, offset: offset)
                },
                shouldRetry: { error, attempt in
                    self.shouldRetry(error: error, attempt: attempt)
                }
            )
            
            // Cache successful response
            await cache.setCachedContests(contests, for: context.broadcastId)
            
            // Log metrics
            let metrics = EngagementRequestMetrics(
                endpoint: "/v1/engagement/contests",
                broadcastId: context.broadcastId,
                duration: Date().timeIntervalSince(startTime),
                statusCode: 200,
                error: nil,
                responseSize: nil,
                retryCount: retryCount
            )
            metrics.log()
            
            return contests
            
        } catch {
            // Log metrics with error
            let metrics = EngagementRequestMetrics(
                endpoint: "/v1/engagement/contests",
                broadcastId: context.broadcastId,
                duration: Date().timeIntervalSince(startTime),
                statusCode: nil,
                error: error,
                responseSize: nil,
                retryCount: retryCount
            )
            metrics.log()
            
            VioLogger.error(
                "Failed to load contests after \(retryCount) attempts: \(error)",
                component: "BackendEngagementRepository"
            )
            return []
        }
    }
    
    func voteInPoll(
        pollId: String,
        optionId: String,
        broadcastContext: BroadcastContext,
        userId: String? = nil
    ) async throws {
        let startTime = Date()
        var retryCount = 0
        
        // Invalidate cache for this broadcast after voting
        defer {
            Task {
                await cache.invalidateCache(for: broadcastContext.broadcastId)
            }
        }
        
        do {
            let effectiveUserId = userId ?? getOrCreateUserId()
            try await retryHandler.execute(
                operation: {
                    retryCount += 1
                    return try await self.submitVoteToBackend(
                        pollId: pollId,
                        optionId: optionId,
                        broadcastContext: broadcastContext,
                        userId: effectiveUserId
                    )
                },
                shouldRetry: { error, attempt in
                    self.shouldRetry(error: error, attempt: attempt)
                }
            )
            
            // Log metrics
            let metrics = EngagementRequestMetrics(
                endpoint: "/v1/engagement/polls/\(pollId)/vote",
                broadcastId: broadcastContext.broadcastId,
                duration: Date().timeIntervalSince(startTime),
                statusCode: 200,
                error: nil,
                responseSize: nil,
                retryCount: retryCount
            )
            metrics.log()
            
        } catch {
            // Log metrics with error
            let metrics = EngagementRequestMetrics(
                endpoint: "/v1/engagement/polls/\(pollId)/vote",
                broadcastId: broadcastContext.broadcastId,
                duration: Date().timeIntervalSince(startTime),
                statusCode: nil,
                error: error,
                responseSize: nil,
                retryCount: retryCount
            )
            metrics.log()
            
            // Convert to EngagementError
            if let httpError = error as? EngagementError {
                throw httpError
            } else if let urlError = error as? URLError {
                throw EngagementError.networkError(urlError)
            } else {
                throw EngagementError.voteFailed(statusCode: -1, message: error.localizedDescription)
            }
        }
    }
    
    func participateInContest(
        contestId: String,
        broadcastContext: BroadcastContext,
        answers: [String: String]?,
        userId: String? = nil
    ) async throws {
        let startTime = Date()
        var retryCount = 0
        
        // Invalidate cache for this broadcast after participation
        defer {
            Task {
                await cache.invalidateCache(for: broadcastContext.broadcastId)
            }
        }
        
        do {
            let effectiveUserId = userId ?? getOrCreateUserId()
            try await retryHandler.execute(
                operation: {
                    retryCount += 1
                    return try await self.submitContestParticipationToBackend(
                        contestId: contestId,
                        broadcastContext: broadcastContext,
                        answers: answers,
                        userId: effectiveUserId
                    )
                },
                shouldRetry: { error, attempt in
                    self.shouldRetry(error: error, attempt: attempt)
                }
            )
            
            // Log metrics
            let metrics = EngagementRequestMetrics(
                endpoint: "/v1/engagement/contests/\(contestId)/participate",
                broadcastId: broadcastContext.broadcastId,
                duration: Date().timeIntervalSince(startTime),
                statusCode: 200,
                error: nil,
                responseSize: nil,
                retryCount: retryCount
            )
            metrics.log()
            
        } catch {
            // Log metrics with error
            let metrics = EngagementRequestMetrics(
                endpoint: "/v1/engagement/contests/\(contestId)/participate",
                broadcastId: broadcastContext.broadcastId,
                duration: Date().timeIntervalSince(startTime),
                statusCode: nil,
                error: error,
                responseSize: nil,
                retryCount: retryCount
            )
            metrics.log()
            
            // Convert to EngagementError
            if let httpError = error as? EngagementError {
                throw httpError
            } else if let urlError = error as? URLError {
                throw EngagementError.networkError(urlError)
            } else {
                throw EngagementError.participationFailed(statusCode: -1, message: error.localizedDescription)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Get or create a persistent userId for engagement tracking
    private func getOrCreateUserId() -> String {
        // Try to get userId from UserDefaults first
        if let existingUserId = UserDefaults.standard.string(forKey: Self.userIdStorageKey), !existingUserId.isEmpty {
            return existingUserId
        }
        
        // Generate a new UUID and store it
        let newUserId = UUID().uuidString
        UserDefaults.standard.set(newUserId, forKey: Self.userIdStorageKey)
        return newUserId
    }
    
    /// Fetch polls from backend
    private func fetchPollsFromBackend(for context: BroadcastContext, limit: Int?, offset: Int?) async throws -> [Poll] {
        let config = VioConfiguration.shared
        let apiKey = config.apiKey
        
        guard !apiKey.isEmpty else {
            throw EngagementError.invalidData(["API key is empty"])
        }
        
        // Build URL using URLComponents for safety
        guard var components = URLComponents(string: campaignRestAPIBaseURL) else {
            throw EngagementError.invalidURL
        }
        
        components.path = "/v1/engagement/polls"
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "broadcastId", value: context.broadcastId),
            URLQueryItem(name: "matchId", value: context.broadcastId) // backward compatibility
        ]
        
        // Add pagination parameters if provided
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw EngagementError.invalidURL
        }
        
        // Build request with API key in header
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 10.0
        
        // Perform request
        let (data, response) = try await networkClient.data(for: request)
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EngagementError.httpError(statusCode: -1, message: "Invalid response type")
        }
        
        // Check for rate limiting
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw EngagementError.rateLimited(retryAfter: retryAfter)
        }
        
        // Check for broadcast not found (404)
        if httpResponse.statusCode == 404 {
            throw EngagementError.broadcastNotFound(broadcastId: context.broadcastId)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw EngagementError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Decode response
        let pollsResponse: PollsResponse
        do {
            pollsResponse = try JSONDecoder().decode(PollsResponse.self, from: data)
        } catch let decodingError as DecodingError {
            throw EngagementError.decodingError(decodingError)
        } catch {
            // If it's not a DecodingError, wrap it
            throw EngagementError.decodingError(DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: error.localizedDescription
                )
            ))
        }
        
        // Set broadcastStartTime in VideoSyncManager if available
        if let broadcastStartTime = pollsResponse.broadcastStartTime ?? pollsResponse.matchStartTime {
            await VideoSyncManager.shared.setBroadcastStartTime(broadcastStartTime, for: context.broadcastId)
        }
        
        // Validate and convert to Poll models
        var polls: [Poll] = []
        var validationErrors: [String] = []
        
        for pollData in pollsResponse.polls {
            // Validate data
            let validation = EngagementDataValidator.validate(pollData)
            if !validation.isValid {
                validationErrors.append("Poll \(pollData.id): \(validation.errors.joined(separator: ", "))")
                continue
            }
            
            // Use broadcastStartTime from poll data if available, otherwise from root level
            let pollBroadcastStartTime = pollData.broadcastStartTime ?? pollData.matchStartTime ?? pollsResponse.broadcastStartTime ?? pollsResponse.matchStartTime
            
            let poll = Poll(
                id: pollData.id,
                broadcastId: pollData.broadcastId ?? pollData.matchId,
                question: pollData.question,
                options: pollData.options.map { option in
                    Poll.PollOption(
                        id: option.id,
                        text: option.text,
                        voteCount: option.voteCount,
                        percentage: option.percentage
                    )
                },
                startTime: pollData.startTime,
                endTime: pollData.endTime,
                videoStartTime: pollData.videoStartTime,
                videoEndTime: pollData.videoEndTime,
                broadcastStartTime: pollBroadcastStartTime,
                isActive: pollData.isActive,
                totalVotes: pollData.totalVotes,
                broadcastContext: context
            )
            polls.append(poll)
        }
        
        // Log validation warnings if any
        if !validationErrors.isEmpty {
            VioLogger.warning(
                "Some polls failed validation: \(validationErrors.joined(separator: "; "))",
                component: "BackendEngagementRepository"
            )
        }
        
        VioLogger.debug("Loaded \(polls.count) polls for broadcastId: \(context.broadcastId)", component: "BackendEngagementRepository")
        return polls
    }
    
    /// Fetch contests from backend
    private func fetchContestsFromBackend(for context: BroadcastContext, limit: Int?, offset: Int?) async throws -> [Contest] {
        let config = VioConfiguration.shared
        let apiKey = config.apiKey
        
        guard !apiKey.isEmpty else {
            throw EngagementError.invalidData(["API key is empty"])
        }
        
        // Build URL using URLComponents for safety
        guard var components = URLComponents(string: campaignRestAPIBaseURL) else {
            throw EngagementError.invalidURL
        }
        
        components.path = "/v1/engagement/contests"
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "broadcastId", value: context.broadcastId),
            URLQueryItem(name: "matchId", value: context.broadcastId) // backward compatibility
        ]
        
        // Add pagination parameters if provided
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        if let offset = offset {
            queryItems.append(URLQueryItem(name: "offset", value: String(offset)))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw EngagementError.invalidURL
        }
        
        // Build request with API key in header
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 10.0
        
        // Perform request
        let (data, response) = try await networkClient.data(for: request)
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EngagementError.httpError(statusCode: -1, message: "Invalid response type")
        }
        
        // Check for rate limiting
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw EngagementError.rateLimited(retryAfter: retryAfter)
        }
        
        // Check for broadcast not found (404)
        if httpResponse.statusCode == 404 {
            throw EngagementError.broadcastNotFound(broadcastId: context.broadcastId)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw EngagementError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Decode response
        let contestsResponse: ContestsResponse
        do {
            contestsResponse = try JSONDecoder().decode(ContestsResponse.self, from: data)
        } catch let decodingError as DecodingError {
            throw EngagementError.decodingError(decodingError)
        } catch {
            // If it's not a DecodingError, wrap it
            throw EngagementError.decodingError(DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: error.localizedDescription
                )
            ))
        }
        
        // Set broadcastStartTime in VideoSyncManager if available
        if let broadcastStartTime = contestsResponse.broadcastStartTime ?? contestsResponse.matchStartTime {
            await VideoSyncManager.shared.setBroadcastStartTime(broadcastStartTime, for: context.broadcastId)
        }
        
        // Validate and convert to Contest models
        var contests: [Contest] = []
        var validationErrors: [String] = []
        
        for contestData in contestsResponse.contests {
            // Validate data
            let validation = EngagementDataValidator.validate(contestData)
            if !validation.isValid {
                validationErrors.append("Contest \(contestData.id): \(validation.errors.joined(separator: ", "))")
                continue
            }
            
            let contestType: Contest.ContestType = contestData.contestType == "quiz" ? .quiz : .giveaway
            
            // Use broadcastStartTime from contest data if available, otherwise from root level
            let contestBroadcastStartTime = contestData.broadcastStartTime ?? contestData.matchStartTime ?? contestsResponse.broadcastStartTime ?? contestsResponse.matchStartTime
            
            let contest = Contest(
                id: contestData.id,
                broadcastId: contestData.broadcastId ?? contestData.matchId,
                title: contestData.title,
                description: contestData.description,
                prize: contestData.prize,
                contestType: contestType,
                startTime: contestData.startTime,
                endTime: contestData.endTime,
                videoStartTime: contestData.videoStartTime,
                videoEndTime: contestData.videoEndTime,
                broadcastStartTime: contestBroadcastStartTime,
                isActive: contestData.isActive,
                broadcastContext: context
            )
            contests.append(contest)
        }
        
        // Log validation warnings if any
        if !validationErrors.isEmpty {
            VioLogger.warning(
                "Some contests failed validation: \(validationErrors.joined(separator: "; "))",
                component: "BackendEngagementRepository"
            )
        }
        
        VioLogger.debug("Loaded \(contests.count) contests for broadcastId: \(context.broadcastId)", component: "BackendEngagementRepository")
        return contests
    }
    
    /// Submit vote to backend
    private func submitVoteToBackend(
        pollId: String,
        optionId: String,
        broadcastContext: BroadcastContext,
        userId: String
    ) async throws {
        let config = VioConfiguration.shared
        let apiKey = config.apiKey
        
        guard !apiKey.isEmpty else {
            throw EngagementError.invalidData(["API key is empty"])
        }
        
        // Convert pollId and optionId to Int (backend expects Int)
        guard let pollIdInt = Int(pollId) else {
            throw EngagementError.invalidData(["Invalid pollId format: \(pollId)"])
        }
        
        guard let optionIdInt = Int(optionId) else {
            throw EngagementError.invalidData(["Invalid optionId format: \(optionId)"])
        }
        
        // Build URL using URLComponents for safety
        guard var components = URLComponents(string: campaignRestAPIBaseURL) else {
            throw EngagementError.invalidURL
        }
        
        components.path = "/v1/engagement/polls/\(pollIdInt)/vote"
        
        guard let url = components.url else {
            throw EngagementError.invalidURL
        }
        
        // Build request with API key in header
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 10.0
        
        // Build request body with userId
        let body: [String: Any] = [
            "broadcastId": broadcastContext.broadcastId,
            "matchId": broadcastContext.broadcastId, // backward compatibility
            "optionId": optionIdInt,
            "userId": userId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Perform request
        let (data, response) = try await networkClient.data(for: request)
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EngagementError.httpError(statusCode: -1, message: "Invalid response type")
        }
        
        // Check for rate limiting
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw EngagementError.rateLimited(retryAfter: retryAfter)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw EngagementError.voteFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
    
    /// Submit contest participation to backend
    private func submitContestParticipationToBackend(
        contestId: String,
        broadcastContext: BroadcastContext,
        answers: [String: String]?,
        userId: String
    ) async throws {
        let config = VioConfiguration.shared
        let apiKey = config.apiKey
        
        guard !apiKey.isEmpty else {
            throw EngagementError.invalidData(["API key is empty"])
        }
        
        // Convert contestId to Int (backend expects Int)
        guard let contestIdInt = Int(contestId) else {
            throw EngagementError.invalidData(["Invalid contestId format: \(contestId)"])
        }
        
        // Build URL using URLComponents for safety
        guard var components = URLComponents(string: campaignRestAPIBaseURL) else {
            throw EngagementError.invalidURL
        }
        
        components.path = "/v1/engagement/contests/\(contestIdInt)/participate"
        
        guard let url = components.url else {
            throw EngagementError.invalidURL
        }
        
        // Build request with API key in header
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 10.0
        
        // Build request body with userId
        var body: [String: Any] = [
            "broadcastId": broadcastContext.broadcastId,
            "matchId": broadcastContext.broadcastId, // backward compatibility
            "userId": userId
        ]
        
        if let answers = answers {
            body["answers"] = answers
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Perform request
        let (data, response) = try await networkClient.data(for: request)
        
        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EngagementError.httpError(statusCode: -1, message: "Invalid response type")
        }
        
        // Check for rate limiting
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
            throw EngagementError.rateLimited(retryAfter: retryAfter)
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8)
            throw EngagementError.participationFailed(statusCode: httpResponse.statusCode, message: errorMessage)
        }
    }
    
    /// Determine if an error should trigger a retry
    private func shouldRetry(error: Error, attempt: Int) -> Bool {
        // Don't retry on client errors (4xx) except 408 and 429
        if let httpError = error as? EngagementError {
            switch httpError {
            case .httpError(let statusCode, _):
                return RequestRetryHandler.shouldRetryHTTPStatus(statusCode)
            case .rateLimited:
                return true // Retry rate limit errors
            case .networkError(let urlError):
                return RequestRetryHandler.isRetryableURLError(urlError)
            case .decodingError, .invalidData, .invalidURL, .pollNotFound, .contestNotFound, .pollClosed, .alreadyVoted, .broadcastNotFound:
                return false // Don't retry these
            case .voteFailed, .participationFailed:
                return false // These are already final errors
            }
        }
        
        // Check URL errors
        if let urlError = error as? URLError {
            return RequestRetryHandler.isRetryableURLError(urlError)
        }
        
        // Default: don't retry unknown errors
        return false
    }
}

// Response models are now in EngagementResponseModels.swift
