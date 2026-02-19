//
//  CommentaryCard.swift
//  Viaplay
//
//  Molecular component: Play-by-play commentary card
//

import SwiftUI

struct CommentaryCard: View {
    let commentary: CommentaryEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Minute badge
            HStack(spacing: 4) {
                Text("\(commentary.minute)'")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(minWidth: 32)
                
                // Icon if event has one
                if commentary.commentaryType.hasIcon {
                    Image(systemName: commentary.commentaryType.icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor(for: commentary.commentaryType))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.1))
            )
            
            // Commentary text
            Text(commentary.text)
                .font(.system(size: 14))
                .foregroundColor(commentary.isHighlighted ? Color(red: 0.96, green: 0.08, blue: 0.42) : .white.opacity(0.9))
                .fontWeight(commentary.isHighlighted ? .semibold : .regular)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
    
    private func iconColor(for type: CommentaryEvent.CommentaryType) -> Color {
        switch type {
        case .goal: return Color(red: 0.96, green: 0.08, blue: 0.42)
        case .chance: return .orange
        case .card: return .yellow
        case .substitution: return .cyan
        case .corner: return .blue
        case .foul: return .orange
        case .save: return .blue
        case .halftime: return .white.opacity(0.6)
        case .kickoff: return .green
        case .general: return .white
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        CommentaryCard(
            commentary: CommentaryEvent(
                id: "c1",
                videoTimestamp: 2700,
                minute: 45,
                text: "Goal! Pedri gets to the ball, slips Robert Lewandowski (Barcelona) into the area and he scores with a delightful chipped finish to make it 2-1.",
                commentaryType: .goal,
                isHighlighted: true,
                metadata: nil
            )
        )
        
        CommentaryCard(
            commentary: CommentaryEvent(
                id: "c2",
                videoTimestamp: 480,
                minute: 8,
                text: "Rodrygo (Real Madrid) attempts to find a teammate with the corner, but the effort is snuffed out by the goalkeeper.",
                commentaryType: .corner,
                isHighlighted: false,
                metadata: nil
            )
        )
    }
    .padding()
    .background(Color.black)
}
