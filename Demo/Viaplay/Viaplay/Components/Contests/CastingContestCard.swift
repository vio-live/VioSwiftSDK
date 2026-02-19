//
//  CastingContestCard.swift
//  Viaplay
//
//  Component for displaying Casting contest events in the timeline
//  Similar design to HighlightVideoCard but customized for contests
//

import SwiftUI
import VioCore
import VioDesignSystem

struct CastingContestCard: View {
    let contest: CastingContestEvent
    let onParticipate: () -> Void
    
    @State private var showModal = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        let brandConfig = VioConfiguration.shared.brandConfiguration
        let colors = VioColors.adaptive(for: colorScheme)
        
        return VStack(alignment: .leading, spacing: 10) {
            // Header (similar to HighlightVideoCard)
            HStack(spacing: 8) {
                // Brand avatar from config (consistent with brand name)
                Image(VioConfiguration.shared.effectiveBrandConfiguration.iconAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(brandConfig.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            
                            Text(contest.contestType == .quiz ? "Quiz" : "Konkurranse")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.4))
                            
                            Text(contest.displayTime)
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    // Badge alineado a la derecha del nombre
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundColor(colors.info)
                        .padding(.leading, 4)
                }
                
                Spacer()
                
                // Campaign sponsor badge
                CampaignSponsorBadge(
                    maxWidth: 50,
                    maxHeight: 16,
                    alignment: .trailing
                )
            }
            
            // Title and description
            VStack(alignment: .leading, spacing: 4) {
                Text(contest.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineSpacing(1)
                
                Text(contest.description)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(1)
            }
            
            // Prize information
            Text(contest.prize)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.orange)
                .padding(.vertical, 4)
            
            // Contest image (if available) - same margins as highlights
            if let imageAsset = contest.metadata?["imageAsset"] {
                Image(imageAsset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(8)
                    .padding(.vertical, 8)
            }
            
            // Participate button
            Button(action: {
                showModal = true
                onParticipate()
            }) {
                HStack {
                    Spacer()
                    Text("Delta")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange,
                                    Color.orange.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
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
                                    Color.orange.opacity(0.4),
                                    Color.orange.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .sheet(isPresented: $showModal) {
            CastingContestModal(contest: contest) {
                showModal = false
            }
        }
    }
}
