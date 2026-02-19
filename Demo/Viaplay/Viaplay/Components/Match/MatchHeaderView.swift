//
//  MatchHeaderView.swift
//  Viaplay
//
//  Molecular component: Match header with teams and score
//

import SwiftUI
import VioCore
import VioCastingUI

struct MatchHeaderView: View {
    let match: Match
    let homeScore: Int
    let awayScore: Int
    let currentMinute: Int
    let onDismiss: () -> Void
    
    @StateObject private var campaignManager = CampaignManager.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // Sponsor and close button (same row)
            ZStack {
                // Sponsor (absolutely centered) - Campaign logo from CampaignManager
                VStack(spacing: 2) {
                    Text("Sponset av")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    // Campaign logo from CampaignManager
                    if let logoUrl = campaignManager.currentCampaign?.campaignLogo, let url = URL(string: logoUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(height: 18)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 18)
                            case .failure:
                                Image(DemoDataManager.shared.defaultLogo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 18)
                            @unknown default:
                                Image(DemoDataManager.shared.defaultLogo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 18)
                            }
                        }
                    } else {
                        // Fallback to hardcoded logo if no campaign logo
                        Image(DemoDataManager.shared.defaultLogo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 18)
                    }
                }
                
                // Close button (positioned right)
                HStack {
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 5)
            
            // Teams and Score (smaller logos)
            HStack(spacing: 12) {
                TeamLogoView(
                    team: match.homeTeam,
                    size: 50,  // Smaller: was 60
                    imageUrl: "https://upload.wikimedia.org/wikipedia/en/thumb/4/47/FC_Barcelona_%28crest%29.svg/200px-FC_Barcelona_%28crest%29.svg.png"
                )
                .frame(maxWidth: .infinity)
                
                MatchScoreView(
                    homeScore: homeScore,
                    awayScore: awayScore,
                    currentMinute: currentMinute
                )
                
                TeamLogoView(
                    team: match.awayTeam,
                    size: 50,  // Smaller: was 60
                    imageUrl: "https://upload.wikimedia.org/wikipedia/en/thumb/a/a7/Paris_Saint-Germain_F.C..svg/200px-Paris_Saint-Germain_F.C..svg.png"
                )
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            
            // Match Details
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "soccerball")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    Text(match.competition)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                    Text(match.venue)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
    }
}

#Preview {
    MatchHeaderView(
        match: Match.barcelonaPSG,
        homeScore: 0,
        awayScore: 0,
        currentMinute: 2,
        onDismiss: {}
    )
    .background(Color(hex: "1B1B25"))
}


