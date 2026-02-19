//
//  HighlightCard.swift
//  Viaplay
//
//  Molecular component: Highlight video card
//

import SwiftUI

struct HighlightCard: View {
    let event: MatchEvent?
    let minute: Int?
    let index: Int
    
    init(event: MatchEvent? = nil, minute: Int? = nil, index: Int) {
        self.event = event
        self.minute = minute
        self.index = index
    }
    
    private var displayMinute: Int {
        minute ?? event?.minute ?? (index * 5 + 10)
    }
    
    private var title: String {
        if let event = event, case .goal = event.type {
            return "\(event.player ?? "Goal") - \(event.minute)'"
        }
        return "Highlight \(index + 1)"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Video thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 120, height: 68)
                .overlay(
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.8))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("\(displayMinute)'")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        HighlightCard(
            event: MatchEvent(minute: 13, type: .goal, player: "A. Diallo", team: .home, description: nil, score: "1-0"),
            index: 0
        )
        
        HighlightCard(minute: 45, index: 1)
        
        HighlightCard(index: 2)
    }
    .padding()
    .background(Color(hex: "1B1B25"))
}


