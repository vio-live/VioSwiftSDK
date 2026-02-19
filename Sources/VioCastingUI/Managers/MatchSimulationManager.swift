//
//  MatchSimulationManager.swift
//  VioCastingUI
//

import Foundation
import Combine

@MainActor
public class MatchSimulationManager: ObservableObject {
    @Published public var currentMinute: Int = 0
    @Published public var homeScore: Int = 0
    @Published public var awayScore: Int = 0
    @Published public var events: [MatchEvent] = []
    @Published public var isPlaying: Bool = false

    private var timer: Timer?
    private var eventTimer: Timer?
    private let matchDuration: Int = 90

    private weak var timeline: UnifiedTimelineManager?

    private let simulatedEvents: [(minute: Int, event: () -> MatchEvent)] = [
        (0, { MatchEvent(minute: 0, type: .kickOff, player: nil, team: .home, description: nil, score: "0-0") }),
        (5, { MatchEvent(minute: 5, type: .substitution(on: "A. Scott", off: "T. Adams"), player: "A. Scott", team: .away, description: nil, score: nil) }),
        (13, { MatchEvent(minute: 13, type: .goal, player: "A. Diallo", team: .home, description: nil, score: "1-0") }),
        (18, { MatchEvent(minute: 18, type: .yellowCard, player: "Casemiro", team: .home, description: nil, score: nil) }),
        (25, { MatchEvent(minute: 25, type: .yellowCard, player: "M. Tavernier", team: .away, description: nil, score: nil) }),
        (32, { MatchEvent(minute: 32, type: .goal, player: "B. Mbeumo", team: .home, description: nil, score: "2-0") }),
        (45, { MatchEvent(minute: 45, type: .halfTime, player: nil, team: .home, description: nil, score: "2-0") }),
        (47, { MatchEvent(minute: 47, type: .goal, player: "J. Kluivert", team: .away, description: nil, score: "2-1") }),
        (58, { MatchEvent(minute: 58, type: .substitution(on: "Bruno Fernandes", off: "A. Diallo"), player: "Bruno Fernandes", team: .home, description: nil, score: nil) }),
        (65, { MatchEvent(minute: 65, type: .yellowCard, player: "Álex Jiménez", team: .away, description: nil, score: nil) }),
        (72, { MatchEvent(minute: 72, type: .goal, player: "Matheus Cunha", team: .home, description: nil, score: "3-1") }),
        (78, { MatchEvent(minute: 78, type: .substitution(on: "M. Mount", off: "B. Mbeumo"), player: "M. Mount", team: .home, description: nil, score: nil) }),
        (85, { MatchEvent(minute: 85, type: .redCard, player: "T. Adams", team: .away, description: nil, score: nil) }),
        (90, { MatchEvent(minute: 90, type: .fullTime, player: nil, team: .home, description: nil, score: "3-1") })
    ]

    public init(timeline: UnifiedTimelineManager? = nil) {
        self.timeline = timeline
    }

    public func startSimulation() {
        guard !isPlaying else { return }
        isPlaying = true

        if events.isEmpty {
            for simulatedEvent in simulatedEvents {
                let event = simulatedEvent.event()
                events.append(event)
                if let timeline = timeline {
                    addEventToTimeline(event, timeline: timeline)
                }
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.currentMinute < self.matchDuration {
                    self.currentMinute += 1
                    self.updateScore()
                } else {
                    self.stopSimulation()
                }
            }
        }
    }

    private func updateScore() {
        let goalsUpToNow = events.filter { event in
            guard event.minute <= currentMinute else { return false }
            if case .goal = event.type { return true }
            return false
        }
        homeScore = goalsUpToNow.filter { $0.team == .home }.count
        awayScore = goalsUpToNow.filter { $0.team == .away }.count
    }

    public func stopSimulation() {
        timer?.invalidate()
        eventTimer?.invalidate()
        timer = nil
        eventTimer = nil
        isPlaying = false
    }

    public func pauseSimulation() {
        timer?.invalidate()
        eventTimer?.invalidate()
        isPlaying = false
    }

    public func resetSimulation() {
        stopSimulation()
        currentMinute = 0
        homeScore = 0
        awayScore = 0
        events = []
    }

    private func addEventToTimeline(_ event: MatchEvent, timeline: UnifiedTimelineManager) {
        let videoTimestamp = TimeInterval(event.minute * 60)

        switch event.type {
        case .goal:
            timeline.addEvent(MatchGoalEvent(
                id: event.id.uuidString,
                videoTimestamp: videoTimestamp,
                player: event.player ?? "",
                team: event.team == .home ? TimelineTeamSide.home : TimelineTeamSide.away,
                score: event.score ?? "",
                assistBy: nil,
                isOwnGoal: false,
                isPenalty: false,
                metadata: nil
            ))

        case .yellowCard, .redCard:
            timeline.addEvent(MatchCardEvent(
                id: event.id.uuidString,
                videoTimestamp: videoTimestamp,
                player: event.player ?? "",
                team: event.team == .home ? TimelineTeamSide.home : TimelineTeamSide.away,
                cardType: event.type == .yellowCard ? .yellow : .red,
                reason: event.description,
                metadata: nil
            ))

        case .substitution(let playerIn, let playerOut):
            timeline.addEvent(MatchSubstitutionEvent(
                id: event.id.uuidString,
                videoTimestamp: videoTimestamp,
                playerIn: playerIn,
                playerOut: playerOut,
                team: event.team == .home ? TimelineTeamSide.home : TimelineTeamSide.away,
                metadata: nil
            ))

        default:
            break
        }
    }

    public func getCurrentScore() -> String {
        "\(homeScore)-\(awayScore)"
    }
}
