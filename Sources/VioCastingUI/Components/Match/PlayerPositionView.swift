//
//  PlayerPositionView.swift
//  Viaplay
//
//  Player position marker on football field
//

import SwiftUI

struct PlayerPositionView: View {
    let player: FieldPlayer
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            // Player circle with number (smaller)
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    )
                
                Text("\(player.number)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Player name (smaller)
            Text(player.shortName)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.9), radius: 1.5, x: 0, y: 0.5)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

#Preview {
    ZStack {
        Color(red: 0.18, green: 0.29, blue: 0.24)
        
        HStack(spacing: 40) {
            PlayerPositionView(
                player: FieldPlayer(
                    number: 10,
                    name: "Bruno Fernandes",
                    shortName: "Bruno Fernandes",
                    position: .midfielder
                ),
                color: .red
            )
            
            PlayerPositionView(
                player: FieldPlayer(
                    number: 7,
                    name: "Mbappé",
                    shortName: "K. Mbappé",
                    position: .forward
                ),
                color: .blue
            )
        }
        .padding()
    }
}
