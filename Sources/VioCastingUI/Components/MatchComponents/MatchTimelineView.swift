//
//  MatchTimelineView.swift
//  Viaplay
//
//  Componente reutilizable para mostrar timeline de eventos del partido
//

import SwiftUI

struct MatchTimelineView: View {
    let timeline: MatchTimeline
    let homeTeam: Team
    let awayTeam: Team
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    // Show events in reverse order (most recent first)
                    ForEach(Array(timeline.events.reversed().enumerated()), id: \.element.id) { index, event in
                        timelineEventRow(event, isLast: index == timeline.events.count - 1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(width: geometry.size.width)
            }
            .frame(width: geometry.size.width)
            .background(Color(hex: "1B1B25"))
        }
    }
    
    // MARK: - Timeline Event Row
    
    private func timelineEventRow(_ event: MatchEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Left side (Home team events)
            if event.team == .home {
                HStack(spacing: 4) {
                    Spacer()
                    
                    eventContent(event)
                }
                .frame(maxWidth: .infinity)
            } else {
                Spacer()
                    .frame(maxWidth: .infinity)
            }
            
            // Center line and minute
            VStack(spacing: 4) {
                // Minute
                Text("\(event.minute)'")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                
                // Vertical line
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: isLast ? 40 : .infinity)
            }
            .frame(width: 32)
            
            // Right side (Away team events)
            if event.team == .away {
                HStack(spacing: 4) {
                    eventContent(event)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                Spacer()
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
    
    // MARK: - Event Content
    
    @ViewBuilder
    private func eventContent(_ event: MatchEvent) -> some View {
        switch event.type {
        case .goal:
            HStack(spacing: 6) {
                if let player = event.player {
                    Text(player)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                Image(systemName: "soccerball")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                
                if let score = event.score {
                    Text(score)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
        case .substitution(let on, let off):
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                    
                    Text(on)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                
                HStack(spacing: 3) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                    
                    Text(off)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            
        case .kickOff:
            Button {
                // Handle kick-off
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "whistle.fill")
                        .font(.system(size: 12))
                    
                    Text("Kick-off")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                )
            }
            
        case .yellowCard:
            HStack(spacing: 8) {
                if let player = event.player {
                    Text(player)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 16, height: 20)
                    .cornerRadius(2)
            }
            
        case .redCard:
            HStack(spacing: 8) {
                if let player = event.player {
                    Text(player)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 16, height: 20)
                    .cornerRadius(2)
            }
            
        default:
            if let description = event.description {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MatchTimelineView(
        timeline: .mock(for: Match.barcelonaPSG),
        homeTeam: Match.barcelonaPSG.homeTeam,
        awayTeam: Match.barcelonaPSG.awayTeam
    )
    .preferredColorScheme(.dark)
}

