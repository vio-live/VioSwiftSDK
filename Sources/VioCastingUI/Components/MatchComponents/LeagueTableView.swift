//
//  LeagueTableView.swift
//  Viaplay
//
//  Componente reutilizable para mostrar tabla de clasificación
//

import SwiftUI

struct LeagueTableView: View {
    let leagueTable: LeagueTable
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Regular Season")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                
                // Table Header
                tableHeader
                    .padding(.horizontal, 12)
                
                // Teams List
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(leagueTable.teams) { team in
                            teamRow(team)
                                .padding(.horizontal, 12)
                        }
                    }
                }
            }
            .frame(width: geometry.size.width)
            .background(Color(hex: "1B1B25"))
        }
    }
    
    // MARK: - Table Header
    
    private var tableHeader: some View {
        HStack(spacing: 4) {
            Text("#")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 24)
            
            Text("Team")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 4)
            
            Text("GP")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 28)
            
            Text("W")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 24)
            
            Text("D")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 24)
            
            Text("L")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 24)
            
            Text("+/-")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 36)
            
            Text("PTS")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 36)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }
    
    // MARK: - Team Row
    
    private func teamRow(_ standing: TeamStanding) -> some View {
        HStack(spacing: 4) {
            // Rank
            Text("\(standing.rank)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 24)
            
            // Team Logo and Name
            HStack(spacing: 6) {
                // Logo placeholder
                Circle()
                    .fill(teamColor(for: standing.rank))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(standing.team.shortName.prefix(2)))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                Text(standing.team.shortName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            
            // Stats
            Text("\(standing.gamesPlayed)")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 28)
            
            Text("\(standing.wins)")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 24)
            
            Text("\(standing.draws)")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 24)
            
            Text("\(standing.losses)")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 24)
            
            // Goal Difference
            Text(goalDifferenceText(standing.goalDifference))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(standing.goalDifference >= 0 ? .green : .red)
                .frame(width: 36)
            
            // Points
            Text("\(standing.points)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }
    
    // MARK: - Helpers
    
    private func teamColor(for rank: Int) -> Color {
        if rank <= 3 {
            return .green
        } else if rank <= 5 {
            return .purple
        } else {
            return .white.opacity(0.2)
        }
    }
    
    private func goalDifferenceText(_ diff: Int) -> String {
        if diff > 0 {
            return "+\(diff)"
        } else {
            return "\(diff)"
        }
    }
}

// MARK: - Preview

#Preview {
    LeagueTableView(leagueTable: .premierLeague)
        .preferredColorScheme(.dark)
}

