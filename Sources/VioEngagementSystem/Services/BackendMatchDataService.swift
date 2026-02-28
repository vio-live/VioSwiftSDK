//
//  BackendMatchDataService.swift
//  VioEngagementSystem
//
//  Fetches match data from Vio backend: score, stats, live scores.
//  Data is manually entered by admin in dashboard — external feeds connected later.
//

import Foundation
import VioCore

// MARK: - Models

public struct MatchScore: Codable {
    public let homeTeam: MatchTeam
    public let awayTeam: MatchTeam
    public let minute: Int
    public let status: MatchStatus
    
    public enum MatchStatus: String, Codable {
        case prematch, live, halftime, finished
    }
}

public struct MatchTeam: Codable {
    public let name: String
    public let logo: String?
    public let score: Int
}

public struct MatchStats: Codable {
    public let stats: [MatchStat]
}

public struct MatchStat: Codable, Identifiable {
    public var id: String { name }
    public let name: String
    public let home: Double
    public let away: Double
}

public struct LiveScores: Codable {
    public let matches: [LiveMatch]
}

public struct LiveMatch: Codable, Identifiable {
    public let id: String
    public let homeTeam: String
    public let awayTeam: String
    public let score: String
    public let minute: Int?
    public let competition: String
    public let status: String
}

// MARK: - Service

@MainActor
public class BackendMatchDataService: ObservableObject {
    
    public static let shared = BackendMatchDataService()
    
    @Published public var score: MatchScore?
    @Published public var stats: MatchStats?
    @Published public var liveScores: LiveScores?
    @Published public var isLoading = false
    
    private var baseURL: String {
        VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
    }
    
    private var apiKey: String {
        let c = VioConfiguration.shared.campaignConfiguration
        if !c.campaignApiKey.isEmpty { return c.campaignApiKey }
        if !c.campaignAdminApiKey.isEmpty { return c.campaignAdminApiKey }
        return VioConfiguration.shared.apiKey
    }
    
    private var pollingTask: Task<Void, Never>?
    private var currentBroadcastId: String?
    private var currentCountry: String = "NO"
    
    private init() {}
    
    // MARK: - Public API
    
    public func loadAll(broadcastId: String, country: String = "NO") async {
        currentBroadcastId = broadcastId
        currentCountry = country
        isLoading = true
        async let scoreTask = fetchScore(broadcastId: broadcastId)
        async let statsTask = fetchStats(broadcastId: broadcastId)
        async let liveScoresTask = fetchLiveScores(country: country)
        score = await scoreTask
        stats = await statsTask
        liveScores = await liveScoresTask
        isLoading = false
    }
    
    /// Start polling fallback (call when WebSocket disconnects)
    public func startPolling(interval: TimeInterval = 30) {
        guard let broadcastId = currentBroadcastId else { return }
        stopPolling()
        VioLogger.debug("Starting score polling every \(Int(interval))s", component: "BackendMatchDataService")
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                score = await fetchScore(broadcastId: broadcastId)
            }
        }
    }
    
    /// Stop polling fallback (call when WebSocket reconnects)
    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        VioLogger.debug("Score polling stopped", component: "BackendMatchDataService")
    }
    
    // MARK: - Score
    
    public func fetchScore(broadcastId: String) async -> MatchScore? {
        guard let url = URL(string: "\(baseURL)/v1/sdk/broadcasts/\(broadcastId)/score?apiKey=\(apiKey)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(MatchScore.self, from: data)
        } catch {
            VioLogger.warning("Score fetch failed: \(error.localizedDescription)", component: "BackendMatchDataService")
            return nil
        }
    }
    
    // MARK: - Stats
    
    public func fetchStats(broadcastId: String) async -> MatchStats? {
        guard let url = URL(string: "\(baseURL)/v1/sdk/broadcasts/\(broadcastId)/stats?apiKey=\(apiKey)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(MatchStats.self, from: data)
        } catch {
            VioLogger.warning("Stats fetch failed: \(error.localizedDescription)", component: "BackendMatchDataService")
            return nil
        }
    }
    
    // MARK: - Live Scores
    
    public func fetchLiveScores(country: String = "NO") async -> LiveScores? {
        guard let url = URL(string: "\(baseURL)/v1/sdk/livescores?apiKey=\(apiKey)&country=\(country)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode(LiveScores.self, from: data)
        } catch {
            VioLogger.warning("LiveScores fetch failed: \(error.localizedDescription)", component: "BackendMatchDataService")
            return nil
        }
    }
    
    // MARK: - WebSocket score update
    
    /// Called by WebSocketManager when a score_update event arrives
    public func handleScoreUpdate(_ data: [String: Any]) {
        guard
            let home = data["home"] as? Int,
            let away = data["away"] as? Int,
            let minute = data["minute"] as? Int
        else { return }
        
        guard let current = score else { return }
        
        score = MatchScore(
            homeTeam: MatchTeam(name: current.homeTeam.name, logo: current.homeTeam.logo, score: home),
            awayTeam: MatchTeam(name: current.awayTeam.name, logo: current.awayTeam.logo, score: away),
            minute: minute,
            status: current.status
        )
        
        VioLogger.debug("Score updated: \(home)-\(away) min \(minute)", component: "BackendMatchDataService")
    }
}
