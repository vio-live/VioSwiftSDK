//
//  StatPreviewCard.swift
//  Viaplay
//
//  Molecular component: Statistics preview card
//

import SwiftUI
import VioCore
import VioCastingUI

struct StatPreviewCard: View {
    let statistics: MatchStatistics
    let maxStats: Int
    let onViewAll: () -> Void
    
    init(statistics: MatchStatistics, maxStats: Int = 3, onViewAll: @escaping () -> Void = {}) {
        self.statistics = statistics
        self.maxStats = maxStats
        self.onViewAll = onViewAll
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Viaplay branding and sponsor
            HStack(spacing: 8) {
                // Viaplay icon
                Image(DemoDataManager.shared.brandAsset(for: .icon))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(VioConfiguration.shared.effectiveBrandConfiguration.name) Statistics")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Text("Live Stats")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("Oppdatert nå")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Campaign sponsor badge
                CampaignSponsorBadge(
                    maxWidth: 50,
                    maxHeight: 16,
                    alignment: .trailing
                )
            }
            
            VStack(spacing: 12) {
                ForEach(Array(statistics.stats.prefix(maxStats))) { stat in
                    StatBar(
                        name: stat.name,
                        homeValue: stat.homeValue,
                        awayValue: stat.awayValue,
                        unit: stat.unit
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    StatPreviewCard(
        statistics: MatchStatistics.mock(for: Match.barcelonaPSG)
    )
    .padding()
    .background(Color(hex: "1B1B25"))
}


