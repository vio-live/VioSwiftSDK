//
//  LineupService.swift
//  VioCastingUI
//
//  Fetches starting XI lineup from Vio backend (sourced from Sportmonks).
//  Endpoint: GET /v1/sdk/broadcasts/:broadcastId/lineup
//

import Foundation
import VioCore

@MainActor
public class LineupService: ObservableObject {

    public static let shared = LineupService()

    @Published public private(set) var state: LineupState = .idle
    @Published public private(set) var lineup: MatchLineupResponse?

    private var currentBroadcastId: String?
    private var fetchTask: Task<Void, Never>?

    private var restBaseURL: String {
        VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
    }

    private var apiKey: String {
        VioConfiguration.shared.resolvedSdkApiKey
    }

    private init() {}

    // MARK: - Public API

    /// Load lineup for the given broadcastId.
    /// Uses cached result if the same broadcastId was already fetched.
    public func loadLineup(broadcastId: String) {
        guard broadcastId != currentBroadcastId || lineup == nil else { return }
        currentBroadcastId = broadcastId
        fetchTask?.cancel()
        fetchTask = Task {
            await fetch(broadcastId: broadcastId)
        }
    }

    /// Force-refresh lineup (ignore cache)
    public func refresh(broadcastId: String) {
        lineup = nil
        currentBroadcastId = nil
        loadLineup(broadcastId: broadcastId)
    }

    // MARK: - Fetch

    private func fetch(broadcastId: String) async {
        state = .loading

        let urlString = "\(restBaseURL)/v1/sdk/broadcasts/\(broadcastId)/lineup?apiKey=\(apiKey)"

        guard let url = URL(string: urlString) else {
            state = .error("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard !Task.isCancelled else { return }

            guard let http = response as? HTTPURLResponse else {
                state = .error("Invalid response")
                return
            }

            if http.statusCode == 404 {
                state = .unavailable("No fixture linked to this broadcast")
                return
            }

            guard (200...299).contains(http.statusCode) else {
                state = .error("HTTP \(http.statusCode)")
                return
            }

            let decoder = JSONDecoder()
            let result = try decoder.decode(MatchLineupResponse.self, from: data)

            if result.available {
                self.lineup = result
                state = .loaded(result)
                VioLogger.debug("Lineup loaded for \(broadcastId) — home: \(result.home?.players.count ?? 0), away: \(result.away?.players.count ?? 0)", component: "Lineup")
            } else {
                state = .unavailable(result.message ?? "Lineup not yet available")
                VioLogger.debug("Lineup not available for \(broadcastId): \(result.message ?? "")", component: "Lineup")
            }

        } catch is CancellationError {
            return
        } catch {
            state = .error(error.localizedDescription)
            VioLogger.error("Lineup fetch failed for \(broadcastId): \(error)", component: "Lineup")
        }
    }
}
