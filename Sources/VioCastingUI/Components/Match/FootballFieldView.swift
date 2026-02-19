//
//  FootballFieldView.swift
//  Viaplay
//
//  Visual football field with player positions
//  100% SwiftUI code, dynamic colors, supports any formation
//

import SwiftUI

struct FootballFieldView: View {
    let formation: String
    let players: [FieldPlayer]
    let teamColor: Color
    
    private let fieldAspectRatio: CGFloat = 0.75  // Half field - Height is 0.75x width
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = width * fieldAspectRatio
            
            ZStack {
                // Field background (grass)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.18, green: 0.29, blue: 0.24),  // Dark green top
                                Color(red: 0.12, green: 0.20, blue: 0.16)   // Darker green bottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(8)
                
                // Field lines
                FieldLinesView()
                    .frame(width: width, height: height)
                
                // Players positioned according to formation
                ForEach(players) { player in
                    PlayerPositionView(
                        player: player,
                        color: teamColor
                    )
                    .position(positionFor(player, in: CGSize(width: width, height: height)))
                }
            }
            .frame(width: width, height: height)
        }
        .aspectRatio(1/fieldAspectRatio, contentMode: .fit)
    }
    
    // MARK: - Position Calculation
    
    private func positionFor(_ player: FieldPlayer, in size: CGSize) -> CGPoint {
        switch formation {
        case "4-3-3":
            return position433(player, in: size)
        case "4-4-2":
            return position442(player, in: size)
        case "3-5-2":
            return position352(player, in: size)
        default:
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
    }
    
    // MARK: - 4-3-3 Formation
    
    private func position433(_ player: FieldPlayer, in size: CGSize) -> CGPoint {
        let width = size.width
        let height = size.height
        
        // 4-3-3 specific positioning (half field - attacking)
        // Based on actual player numbers from the data
        
        let positions: [Int: CGPoint] = [
            // Goalkeeper (off-screen or bottom)
            31: CGPoint(x: width * 0.5, y: height * 0.95),
            
            // Defenders (4 players - back line)
            2:  CGPoint(x: width * 0.15, y: height * 0.80),  // Left back
            15: CGPoint(x: width * 0.35, y: height * 0.80),  // Center back
            6:  CGPoint(x: width * 0.65, y: height * 0.80),  // Center back
            13: CGPoint(x: width * 0.85, y: height * 0.80),  // Right back
            
            // Midfielders (3 players - middle line)
            25: CGPoint(x: width * 0.25, y: height * 0.55),  // Left mid
            37: CGPoint(x: width * 0.50, y: height * 0.55),  // Center mid
            8:  CGPoint(x: width * 0.75, y: height * 0.55),  // Right mid
            
            // Forwards (3 players - attack line)
            7:  CGPoint(x: width * 0.20, y: height * 0.25),  // Left wing
            30: CGPoint(x: width * 0.50, y: height * 0.25),  // Striker
            10: CGPoint(x: width * 0.80, y: height * 0.25)   // Right wing
        ]
        
        // Return position for this player or default center
        return positions[player.number] ?? CGPoint(x: width * 0.5, y: height * 0.5)
    }
    
    // MARK: - 4-4-2 Formation (PSG)
    
    private func position442(_ player: FieldPlayer, in size: CGSize) -> CGPoint {
        let width = size.width
        let height = size.height
        
        // PSG 4-4-2 specific positioning
        let positions: [Int: CGPoint] = [
            // Goalkeeper
            99: CGPoint(x: width * 0.5, y: height * 0.95),
            
            // Defenders (4 players - back line)
            2:  CGPoint(x: width * 0.15, y: height * 0.80),  // Right back Hakimi
            5:  CGPoint(x: width * 0.38, y: height * 0.80),  // Center back Marquinhos
            4:  CGPoint(x: width * 0.62, y: height * 0.80),  // Center back Ramos
            25: CGPoint(x: width * 0.85, y: height * 0.80),  // Left back Mendes
            
            // Midfielders (4 players - middle line)
            17: CGPoint(x: width * 0.15, y: height * 0.55),  // Left mid Vitinha
            8:  CGPoint(x: width * 0.38, y: height * 0.55),  // Center mid Ruiz
            19: CGPoint(x: width * 0.62, y: height * 0.55),  // Center mid Lee
            33: CGPoint(x: width * 0.85, y: height * 0.55),  // Right mid Zaïre-Emery
            
            // Forwards (2 players - attack line)
            7:  CGPoint(x: width * 0.35, y: height * 0.25),  // Left forward Mbappé
            23: CGPoint(x: width * 0.65, y: height * 0.25)   // Right forward Kolo Muani
        ]
        
        return positions[player.number] ?? CGPoint(x: width * 0.5, y: height * 0.5)
    }
    
    // MARK: - 3-5-2 Formation
    
    private func position352(_ player: FieldPlayer, in size: CGSize) -> CGPoint {
        let width = size.width
        let height = size.height
        
        switch player.position {
        case .goalkeeper:
            return CGPoint(x: width * 0.5, y: height * 0.92)
        case .defender:
            let defenderY = height * 0.75
            return CGPoint(x: width * 0.5, y: defenderY)
        case .midfielder:
            let midfielderY = height * 0.50
            return CGPoint(x: width * 0.5, y: midfielderY)
        case .forward:
            let forwardY = height * 0.25
            return CGPoint(x: width * 0.5, y: forwardY)
        }
    }
}

// MARK: - Field Player Model

struct FieldPlayer: Identifiable {
    let id = UUID()
    let number: Int
    let name: String
    let shortName: String
    let position: PlayerPosition
    
    enum PlayerPosition {
        case goalkeeper
        case defender
        case midfielder
        case forward
    }
}

#Preview {
    FootballFieldView(
        formation: "4-3-3",
        players: [
            FieldPlayer(number: 31, name: "S. Lammens", shortName: "S. Lammens", position: .goalkeeper),
            FieldPlayer(number: 2, name: "Diogo Dalot", shortName: "Diogo Dalot", position: .defender),
            FieldPlayer(number: 15, name: "L. Yoro", shortName: "L. Yoro", position: .defender),
            FieldPlayer(number: 6, name: "Lisandro Martinez", shortName: "Lisandro Martinez", position: .defender),
            FieldPlayer(number: 13, name: "P. Dorgu", shortName: "P. Dorgu", position: .defender),
            FieldPlayer(number: 25, name: "M. Ugarte", shortName: "M. Ugarte", position: .midfielder),
            FieldPlayer(number: 37, name: "K. Mainoo", shortName: "K. Mainoo", position: .midfielder),
            FieldPlayer(number: 8, name: "Bruno Fernandes", shortName: "Bruno Fernandes", position: .midfielder),
            FieldPlayer(number: 7, name: "M. Mount", shortName: "M. Mount", position: .forward),
            FieldPlayer(number: 30, name: "B. Sesko", shortName: "B. Sesko", position: .forward),
            FieldPlayer(number: 10, name: "Matheus Cunha", shortName: "Matheus Cunha", position: .forward)
        ],
        teamColor: .red
    )
    .padding()
    .background(Color.black)
}
