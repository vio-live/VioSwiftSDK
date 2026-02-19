//
//  FinalStatsCard.swift
//  Viaplay
//
//  Modular component: Final match statistics
//  Reusable for any match
//

import SwiftUI
import VioCore
import VioDesignSystem

struct FinalStatsCard: View {
    let statistics: MatchStatistics
    let homeScore: Int
    let awayScore: Int
    
    private var winningTeam: String? {
        if homeScore > awayScore {
            return statistics.homeTeam.name
        } else if awayScore > homeScore {
            return statistics.awayTeam.name
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(DemoDataManager.shared.brandAsset(for: .icon))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sluttstatistikk")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Text("Fulltid")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        
                        if let winner = winningTeam {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text("Vinner: \(winner)")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                // Campaign sponsor badge
                CampaignSponsorBadge(
                    maxWidth: 50,
                    maxHeight: 16,
                    alignment: HorizontalAlignment.trailing
                )
            }
            
            // Final score
            HStack {
                Text("\(statistics.homeTeam.name)")
                    .font(.system(size: 14, weight: homeScore > awayScore ? .bold : .medium))
                    .foregroundColor(homeScore > awayScore ? .green : .white)
                
                Spacer()
                
                Text("\(homeScore) - \(awayScore)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(statistics.awayTeam.name)")
                    .font(.system(size: 14, weight: awayScore > homeScore ? .bold : .medium))
                    .foregroundColor(awayScore > homeScore ? .green : .white)
            }
            .padding(.vertical, 8)
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // All statistics
            VStack(spacing: 10) {
                ForEach(statistics.stats) { stat in
                    StatBar(
                        name: stat.name,
                        homeValue: stat.homeValue,
                        awayValue: stat.awayValue,
                        unit: stat.unit
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.4),
                                    Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

#Preview {
    FinalStatsCard(
        statistics: MatchStatistics.mock(for: Match.barcelonaPSG),
        homeScore: 3,
        awayScore: 1
    )
    .padding()
    .background(Color.black)
}
