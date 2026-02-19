//
//  MatchLineupView.swift
//  Viaplay
//
//  Componente reutilizable para mostrar alineaciones en campo de fútbol
//

import SwiftUI

struct MatchLineupView: View {
    let homeLineup: TeamLineup
    let awayLineup: TeamLineup
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 20) {
                    // Home Team
                    teamLineupSection(homeLineup, isHome: true)
                        .frame(width: geometry.size.width - 24)
                    
                    // Football Pitch
                    footballPitchView
                        .frame(width: geometry.size.width - 24)
                    
                    // Away Team
                    teamLineupSection(awayLineup, isHome: false)
                        .frame(width: geometry.size.width - 24)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(width: geometry.size.width)
            }
            .frame(width: geometry.size.width)
            .background(Color(hex: "1B1B25"))
        }
    }
    
    // MARK: - Team Lineup Section
    
    private func teamLineupSection(_ lineup: TeamLineup, isHome: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Team Header
            HStack {
                Text(lineup.team.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(lineup.formation)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Players Grid
            let playersByPosition = groupPlayersByPosition(lineup.players)
            
            VStack(spacing: 12) {
                // Goalkeeper
                if let gk = playersByPosition[.goalkeeper]?.first {
                    playerRow(gk, isHome: isHome)
                }
                
                // Defenders
                if let defenders = playersByPosition[.defender] {
                    HStack(spacing: 4) {
                        ForEach(defenders) { player in
                            playerCircle(player, isHome: isHome)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Midfielders
                if let midfielders = playersByPosition[.midfielder] {
                    HStack(spacing: 4) {
                        ForEach(midfielders) { player in
                            playerCircle(player, isHome: isHome)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Forwards
                if let forwards = playersByPosition[.forward] {
                    HStack(spacing: 4) {
                        ForEach(forwards) { player in
                            playerCircle(player, isHome: isHome)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
    
    // MARK: - Football Pitch View
    
    private var footballPitchView: some View {
        GeometryReader { geometry in
            ZStack {
                // Pitch background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "2C2D36"))
                
                // Pitch lines
                VStack(spacing: 0) {
                    // Top penalty area
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: geometry.size.height * 0.15)
                    
                    // Center circle area
                    Spacer()
                    
                    // Center line
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 2)
                    
                    Spacer()
                    
                    // Bottom penalty area
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: geometry.size.height * 0.15)
                }
                
                // Center circle
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: geometry.size.width * 0.3)
                
                // Players on pitch
                VStack(spacing: 0) {
                    // Home team (top)
                    HStack(spacing: 4) {
                        ForEach(homeLineup.players.filter { $0.position != .goalkeeper }.prefix(10)) { player in
                            playerCircleOnPitch(player, isHome: true)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 8)
                    
                    Spacer()
                    
                    // Away team (bottom)
                    HStack(spacing: 4) {
                        ForEach(awayLineup.players.filter { $0.position != .goalkeeper }.prefix(10)) { player in
                            playerCircleOnPitch(player, isHome: false)
                        }
                    }
                    .padding(.bottom, 20)
                    .padding(.horizontal, 8)
                }
            }
        }
        .frame(height: 400)
    }
    
    // MARK: - Player Circle
    
    private func playerCircle(_ player: Player, isHome: Bool) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(isHome ? Color.red : Color.blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("\(player.number)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                )
            
            Text(player.name.components(separatedBy: " ").last ?? "")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func playerCircleOnPitch(_ player: Player, isHome: Bool) -> some View {
        Circle()
            .fill(isHome ? Color.red : Color.blue)
            .frame(width: 32, height: 32)
            .overlay(
                Text("\(player.number)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            )
            .frame(maxWidth: .infinity)
    }
    
    // MARK: - Player Row
    
    private func playerRow(_ player: Player, isHome: Bool) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isHome ? Color.red : Color.blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Text("\(player.number)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )
            
            Text(player.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            if player.isCaptain {
                Image(systemName: "c.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
            }
            
            Spacer()
            
            Text(player.position.displayName)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - Helpers
    
    private func groupPlayersByPosition(_ players: [Player]) -> [Player.PlayerPosition: [Player]] {
        Dictionary(grouping: players, by: { $0.position })
    }
}

// MARK: - Preview

#Preview {
    MatchLineupView(
        homeLineup: .mockHome(for: Match.barcelonaPSG),
        awayLineup: .mockAway(for: Match.barcelonaPSG)
    )
    .preferredColorScheme(.dark)
}

