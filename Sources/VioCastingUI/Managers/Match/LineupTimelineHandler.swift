//
//  LineupTimelineHandler.swift
//  VioCastingUI
//
//  Handles `lineup_show` WebSocket events.
//
//  Flow:
//    1. WS fires lineup_show with videoTimestamp
//    2. LineupService data used if already cached; otherwise fetch is triggered
//       and state is observed via Combine — no polling, no Task.sleep
//    3. Two LineupTimelineEvents (home + away) injected into UnifiedTimelineManager
//       at the received videoTimestamp, with players embedded in the event itself
//
//  Hardcoded demo data in TimelineDataGenerator is NOT touched —
//  this handler only runs in the live / backend-driven path.
//

import Foundation
import Combine
import VioCore

@MainActor
public class LineupTimelineHandler {

    private weak var timeline: UnifiedTimelineManager?
    private var lineupService: LineupService { .shared }
    private var cancellable: AnyCancellable?

    public init(timeline: UnifiedTimelineManager) {
        self.timeline = timeline
    }

    // MARK: - Entry point

    /// Call this when a `lineup_show` WS event arrives.
    public func handle(event: LineupShowEvent, broadcastId: String) {
        let ts = event.videoTimestamp
        cancellable = nil   // cancel any pending observation

        // Already loaded → inject immediately, no async work needed
        if let cached = lineupService.lineup {
            inject(lineup: cached, at: ts)
            return
        }

        // Trigger fetch if idle
        lineupService.loadLineup(broadcastId: broadcastId)

        // Observe state via Combine — resolves exactly once
        cancellable = lineupService.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .loaded(let data):
                    self?.inject(lineup: data, at: ts)
                    self?.cancellable = nil   // done

                case .error(let msg):
                    VioLogger.error("lineup_show: fetch failed — \(msg). Lineup not shown.", component: "Lineup")
                    self?.cancellable = nil

                case .unavailable(let msg):
                    VioLogger.warning("lineup_show: lineup unavailable — \(msg)", component: "Lineup")
                    self?.cancellable = nil

                case .loading, .idle:
                    break   // wait for next state
                }
            }
    }

    // MARK: - Inject into timeline

    private func inject(lineup: MatchLineupResponse, at videoTimestamp: TimeInterval) {
        guard let timeline = timeline else { return }

        if let home = lineup.home {
            let event = LineupTimelineEvent(
                id: "lineup-home-\(broadcastSuffix(videoTimestamp))",
                videoTimestamp: videoTimestamp,
                teamKey: "home",
                teamName: home.teamName,
                formation: home.formation,
                teamLogo: home.teamLogo,
                players: home.players
            )
            timeline.addEvent(event)
        }

        if let away = lineup.away {
            let event = LineupTimelineEvent(
                id: "lineup-away-\(broadcastSuffix(videoTimestamp))",
                videoTimestamp: videoTimestamp + 1,   // 1 s apart so both render correctly
                teamKey: "away",
                teamName: away.teamName,
                formation: away.formation,
                teamLogo: away.teamLogo,
                players: away.players
            )
            timeline.addEvent(event)
        }

        VioLogger.success(
            "Lineup injected at ts=\(Int(videoTimestamp))s — home: \(lineup.home?.players.count ?? 0), away: \(lineup.away?.players.count ?? 0)",
            component: "Lineup"
        )
    }

    private func broadcastSuffix(_ ts: TimeInterval) -> String {
        String(Int(ts))
    }
}
