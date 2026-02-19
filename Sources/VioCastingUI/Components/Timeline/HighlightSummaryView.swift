//
//  HighlightSummaryView.swift
//  Viaplay
//
//  Organism component: Match highlights summary (like BBC Sport)
//  Shows goals, cards, substitutions in chronological order
//

import SwiftUI

struct HighlightSummaryView: View {
    let highlights: [HighlightTimelineEvent]
    let matchEvents: [MatchEvent]
    @ObservedObject var timeline: UnifiedTimelineManager
    
    @State private var selectedVideo: HighlightTimelineEvent?
    
    // Use timeline's current video time (same as All and Chat)
    private var currentVideoTime: TimeInterval {
        timeline.currentVideoTime
    }
    
    private var displayMinute: Int {
        Int(currentVideoTime / 60)
    }
    
    // Combine all events for summary (filtered by timeline)
    private var summaryEvents: [SummaryEvent] {
        var events: [SummaryEvent] = []
        
        print("🎬 [HighlightSummary] Current video time: \(currentVideoTime)s (\(displayMinute)')")
        print("🎬 [HighlightSummary] Total match events: \(matchEvents.count)")
        
        // Filter by videoTimestamp (same as All tab)
        let visibleEvents = matchEvents.filter { 
            TimeInterval($0.minute * 60) <= currentVideoTime 
        }
        
        print("🎬 [HighlightSummary] Visible events after filter: \(visibleEvents.count)")
        
        // Add match events (goals, cards, subs)
        for matchEvent in visibleEvents {
            // Only show important events (goals, cards, subs)
            switch matchEvent.type {
            case .goal, .yellowCard, .redCard, .substitution:
                print("🎬 [HighlightSummary] Adding event: \(matchEvent.minute)' \(matchEvent.type)")
                events.append(SummaryEvent(
                    id: matchEvent.id.uuidString,
                    minute: matchEvent.minute,
                    type: eventType(from: matchEvent),
                    player: matchEvent.player ?? "",
                    team: matchEvent.team == .home ? "Barcelona" : "Real Madrid",
                    score: matchEvent.score,
                    assistBy: nil,
                    hasVideo: hasVideo(for: matchEvent),
                    videoHighlight: videoForEvent(matchEvent)
                ))
            default:
                break
            }
        }
        
        print("🎬 [HighlightSummary] Total summary events: \(events.count)")
        return events
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Only show halves that are visible in timeline
                if displayMinute >= 1 && summaryEvents.contains(where: { $0.minute <= 45 }) {
                    halfSection(
                        title: "1ST HALF",
                        score: calculateHalfScore(events: summaryEvents.filter { $0.minute <= 45 }),
                        events: summaryEvents.filter { $0.minute <= 45 }
                    )
                }
                
                if displayMinute > 45 && summaryEvents.contains(where: { $0.minute > 45 }) {
                    halfSection(
                        title: "2ND HALF",
                        score: calculateHalfScore(events: summaryEvents.filter { $0.minute > 45 }),
                        events: summaryEvents.filter { $0.minute > 45 }
                    )
                }
                
                // Empty state when no events yet
                if summaryEvents.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("Ingen hendelser ennå")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Venter på kampstart...")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color.black)
        .fullScreenCover(item: $selectedVideo) { highlight in
            if let clipUrl = highlight.clipUrl, let url = URL(string: clipUrl) {
                HighlightVideoPlayerView(videoURL: url, title: highlight.title) {
                    selectedVideo = nil
                }
            }
        }
    }
    
    @ViewBuilder
    private func halfSection(title: String, score: String, events: [SummaryEvent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
                
                Text(score)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
            
            // Events
            ForEach(events.sorted { $0.minute < $1.minute }) { event in
                eventRow(event)
            }
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func eventRow(_ event: SummaryEvent) -> some View {
        VStack(spacing: 0) {
            // Event info row
            HStack(alignment: .center, spacing: 12) {
                // Left side (for home team)
                if event.team == "Barcelona" {
                    HStack(spacing: 8) {
                        Text("\(event.minute)'")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        eventIcon(type: event.type)
                        
                        if let score = event.score {
                            Text(score)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.player)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            
                            if let assist = event.assistBy {
                                Text("(\(assist))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    
                    Spacer()
                } else {
                    Spacer()
                    
                    // Right side (for away team)
                    HStack(spacing: 8) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(event.player)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                            
                            if let assist = event.assistBy {
                                Text("(\(assist))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        if let score = event.score {
                            Text(score)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        }
                        
                        eventIcon(type: event.type)
                        
                        Text("\(event.minute)'")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Video preview if available
            if let video = event.videoHighlight {
                HighlightVideoCard(highlight: video)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
    }
    
    @ViewBuilder
    private func eventIcon(type: SummaryEventType) -> some View {
        ZStack {
            Circle()
                .fill(iconBackground(for: type))
                .frame(width: 28, height: 28)
            
            Image(systemName: iconName(for: type))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor(for: type))
        }
    }
    
    private func iconName(for type: SummaryEventType) -> String {
        switch type {
        case .goal: return "soccerball.circle.fill"
        case .yellowCard: return "rectangle.fill"
        case .redCard: return "rectangle.fill"
        case .substitution: return "arrow.triangle.2.circlepath"
        }
    }
    
    private func iconColor(for type: SummaryEventType) -> Color {
        switch type {
        case .goal: return .white
        case .yellowCard: return .black
        case .redCard: return .white
        case .substitution: return .green
        }
    }
    
    private func iconBackground(for type: SummaryEventType) -> Color {
        switch type {
        case .goal: return Color.clear
        case .yellowCard: return .yellow
        case .redCard: return .red
        case .substitution: return Color.clear
        }
    }
    
    // MARK: - Helpers
    
    private func eventType(from matchEvent: MatchEvent) -> SummaryEventType {
        switch matchEvent.type {
        case .goal: return .goal
        case .yellowCard: return .yellowCard
        case .redCard: return .redCard
        case .substitution: return .substitution
        default: return .goal
        }
    }
    
    private func hasVideo(for matchEvent: MatchEvent) -> Bool {
        // Check if we have a video highlight for this event
        return videoForEvent(matchEvent) != nil
    }
    
    private func videoForEvent(_ matchEvent: MatchEvent) -> HighlightTimelineEvent? {
        // Match events with video highlights
        let eventMinute = matchEvent.minute
        return highlights.first { abs($0.displayMinute - eventMinute) <= 1 }
    }
    
    private func calculateHalfScore(events: [SummaryEvent]) -> String {
        let homeGoals = events.filter { $0.type == .goal && $0.team == "Barcelona" }.count
        let awayGoals = events.filter { $0.type == .goal && $0.team == "Real Madrid" }.count
        return "\(homeGoals) - \(awayGoals)"
    }
}

// MARK: - Models

struct SummaryEvent: Identifiable {
    let id: String
    let minute: Int
    let type: SummaryEventType
    let player: String
    let team: String
    let score: String?
    let assistBy: String?
    let hasVideo: Bool
    let videoHighlight: HighlightTimelineEvent?
}

enum SummaryEventType {
    case goal
    case yellowCard
    case redCard
    case substitution
}

#Preview {
    HighlightSummaryView(
        highlights: [],
        matchEvents: [
            MatchEvent(minute: 13, type: .goal, player: "A. Diallo", team: .home, description: nil, score: "1-0")
        ],
        timeline: UnifiedTimelineManager()
    )
}
