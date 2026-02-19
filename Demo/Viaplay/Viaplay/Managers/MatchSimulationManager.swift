//
//  MatchSimulationManager.swift
//  Viaplay
//
//  Manager para simular eventos del partido en tiempo real
//  Integrated with UnifiedTimelineManager
//

import Foundation
import Combine
import VioCastingUI

@MainActor
class MatchSimulationManager: ObservableObject {
    @Published var currentMinute: Int = 0
    @Published var homeScore: Int = 0
    @Published var awayScore: Int = 0
    @Published var events: [MatchEvent] = []
    @Published var isPlaying: Bool = false
    
    private var timer: Timer?
    private var eventTimer: Timer?
    private let matchDuration: Int = 90
    
    // Timeline integration (optional)
    private weak var timeline: UnifiedTimelineManager?
    
    // MARK: - Initialization
    
    init(timeline: UnifiedTimelineManager? = nil) {
        self.timeline = timeline
    }
    
    // Eventos predefinidos para simular
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
    
    func startSimulation() {
        guard !isPlaying else { return }
        isPlaying = true
        
        // Pre-load all events at start (for demo purposes)
        if events.isEmpty {
            for simulatedEvent in simulatedEvents {
                let event = simulatedEvent.event()
                events.append(event)
                
                // Add to timeline if available
                if let timeline = timeline {
                    addEventToTimeline(event, timeline: timeline)
                }
            }
            print("⚽ [MatchSimulation] Pre-loaded \(events.count) events")
        }
        
        // Timer para minutos
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
        // Update score based on current minute
        let goalsUpToNow = events.filter { event in
            guard event.minute <= currentMinute else { return false }
            if case .goal = event.type { return true }
            return false
        }
        
        homeScore = goalsUpToNow.filter { $0.team == MatchEvent.TeamSide.home }.count
        awayScore = goalsUpToNow.filter { $0.team == MatchEvent.TeamSide.away }.count
    }
    
    func stopSimulation() {
        timer?.invalidate()
        eventTimer?.invalidate()
        timer = nil
        eventTimer = nil
        isPlaying = false
    }
    
    func pauseSimulation() {
        timer?.invalidate()
        eventTimer?.invalidate()
        isPlaying = false
    }
    
    func resetSimulation() {
        stopSimulation()
        currentMinute = 0
        homeScore = 0
        awayScore = 0
        events = []
    }
    
    private func checkForEvents() {
        // Buscar eventos que deben ocurrir en este minuto
        for simulatedEvent in simulatedEvents {
            if simulatedEvent.minute == currentMinute {
                let event = simulatedEvent.event()
                events.append(event)
                
                // Add to unified timeline if available
                if let timeline = timeline {
                    addEventToTimeline(event, timeline: timeline)
                }
                
                // Actualizar marcador si es un gol
                if case .goal = event.type {
                    if event.team == .home {
                        homeScore += 1
                    } else {
                        awayScore += 1
                    }
                }
                
                // Notificar evento
                NotificationCenter.default.post(
                    name: NSNotification.Name("MatchEventOccurred"),
                    object: event
                )
            }
        }
    }
    
    // MARK: - Timeline Integration
    
    private func addEventToTimeline(_ event: MatchEvent, timeline: UnifiedTimelineManager) {
        let videoTimestamp = TimeInterval(event.minute * 60)
        
        switch event.type {
        case .goal:
            timeline.addEvent(MatchGoalEvent(
                id: event.id.uuidString,
                videoTimestamp: videoTimestamp,
                player: event.player ?? "",
                team: event.team == .home ? .home : .away,
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
                team: event.team == .home ? .home : .away,
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
                team: event.team == .home ? .home : .away,
                metadata: nil
            ))
            
        default:
            break
        }
    }
    
    func getCurrentScore() -> String {
        return "\(homeScore)-\(awayScore)"
    }
}


