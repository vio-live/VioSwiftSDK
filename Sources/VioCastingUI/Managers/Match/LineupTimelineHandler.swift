//
//  LineupTimelineHandler.swift
//  VioCastingUI
//
//  Handles `lineup_show` WebSocket events.
//  Flow:
//    1. WS fires lineup_show with videoTimestamp
//    2. Pre-fetched LineupService data used (or fetched on-demand if missing)
//    3. Two AnnouncementEvents (home + away) injected into UnifiedTimelineManager
//       at the received videoTimestamp
//
//  Hardcoded demo data in TimelineDataGenerator is NOT touched —
//  this handler only runs in the live / backend-driven path.
//

import Foundation
import VioCore

@MainActor
public class LineupTimelineHandler {

    private weak var timeline: UnifiedTimelineManager?
    private var lineupService: LineupService { .shared }

    public init(timeline: UnifiedTimelineManager) {
        self.timeline = timeline
    }

    // MARK: - Entry point

    /// Call this when a `lineup_show` WS event arrives.
    public func handle(event: LineupShowEvent, broadcastId: String) {
        let ts = event.videoTimestamp

        // If already loaded, inject immediately
        if let cached = lineupService.lineup {
            inject(lineup: cached, at: ts)
            return
        }

        // Fetch first, then inject
        lineupService.loadLineup(broadcastId: broadcastId)

        // Observe until loaded (poll via Task — lightweight)
        Task {
            for _ in 0..<30 {   // max 15 s (30 × 0.5 s)
                try? await Task.sleep(nanoseconds: 500_000_000)
                if let loaded = lineupService.lineup {
                    inject(lineup: loaded, at: ts)
                    return
                }
                if case .error = lineupService.state { return }
                if case .unavailable = lineupService.state { return }
            }
            VioLogger.warning("lineup_show: lineup not available after 15 s — skipping injection", component: "Lineup")
        }
    }

    // MARK: - Inject into timeline

    private func inject(lineup: MatchLineupResponse, at videoTimestamp: TimeInterval) {
        guard let timeline = timeline else { return }

        if let home = lineup.home {
            let event = AnnouncementEvent(
                id: "lineup-home-\(Int(videoTimestamp))",
                videoTimestamp: videoTimestamp,
                title: "Oppstilling \(home.teamName)",
                message: "\(home.formation ?? "") · \(home.players.count) spillere",
                imageUrl: home.teamLogo,
                actionUrl: nil,
                actionText: nil,
                metadata: [
                    "type":      "lineup",
                    "team":      "home",
                    "formation": home.formation ?? "",
                    "source":    "backend"   // flag so renderEvent uses real data
                ]
            )
            timeline.addEvent(event)
        }

        if let away = lineup.away {
            let event = AnnouncementEvent(
                id: "lineup-away-\(Int(videoTimestamp))",
                videoTimestamp: videoTimestamp + 1,  // 1 s apart so both appear
                title: "Oppstilling \(away.teamName)",
                message: "\(away.formation ?? "") · \(away.players.count) spillere",
                imageUrl: away.teamLogo,
                actionUrl: nil,
                actionText: nil,
                metadata: [
                    "type":      "lineup",
                    "team":      "away",
                    "formation": away.formation ?? "",
                    "source":    "backend"
                ]
            )
            timeline.addEvent(event)
        }

        VioLogger.success("Lineup injected into timeline at ts=\(videoTimestamp)", component: "Lineup")
    }
}

// MARK: - PlayerInfo mapper

extension LineupPlayer {
    /// Convert backend LineupPlayer to the existing PlayerInfo model used by LineupCard.
    func toPlayerInfo() -> PlayerInfo {
        PlayerInfo(
            number: jerseyNumber ?? 0,
            name: name,
            position: localizedPosition
        )
    }

    private var localizedPosition: String {
        switch position {
        case "goalkeeper": return "Keeper"
        case "defender":   return "Forsvar"
        case "midfielder": return "Midtbane"
        default:           return "Angrep"
        }
    }
}
