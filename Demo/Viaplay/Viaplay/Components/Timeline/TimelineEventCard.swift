//
//  TimelineEventCard.swift
//  Viaplay
//
//  Molecular component: Timeline event card
//

import SwiftUI

struct TimelineEventCard: View {
    let event: MatchEvent
    let showConnector: Bool
    
    init(event: MatchEvent, showConnector: Bool = false) {
        self.event = event
        self.showConnector = showConnector
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TimelineMinuteBadge(
                minute: event.minute,
                showConnector: showConnector
            )
            
            VStack(alignment: .leading, spacing: 8) {
                eventContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    @ViewBuilder
    private var eventContent: some View {
        switch event.type {
        case .goal:
            HStack(spacing: 8) {
                if let player = event.player {
                    Text(player)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Image(systemName: "soccerball")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                
                if let score = event.score {
                    Text(score)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
        case .substitution(let on, let off):
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text(on)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                    Text(off)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
        case .yellowCard:
            HStack(spacing: 8) {
                if let player = event.player {
                    Text(player)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                }
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 20, height: 24)
                    .cornerRadius(3)
            }
            
        case .redCard:
            HStack(spacing: 8) {
                if let player = event.player {
                    Text(player)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                }
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 20, height: 24)
                    .cornerRadius(3)
            }
            
        case .kickOff:
            HStack(spacing: 8) {
                Image(systemName: "whistle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Text("Kick-off")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
            
        case .halfTime:
            Text("Half Time")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            
        case .fullTime:
            Text("Full Time")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            
        default:
            if let description = event.description {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TimelineEventCard(
            event: MatchEvent(minute: 13, type: .goal, player: "A. Diallo", team: .home, description: nil, score: "1-0")
        )
        
        TimelineEventCard(
            event: MatchEvent(minute: 18, type: .yellowCard, player: "Casemiro", team: .home, description: nil, score: nil),
            showConnector: true
        )
        
        TimelineEventCard(
            event: MatchEvent(minute: 5, type: .substitution(on: "A. Scott", off: "T. Adams"), player: "A. Scott", team: .away, description: nil, score: nil)
        )
    }
    .padding()
    .background(Color(hex: "1B1B25"))
}


