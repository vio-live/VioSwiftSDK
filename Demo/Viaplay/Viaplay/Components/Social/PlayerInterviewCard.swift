//
//  PlayerInterviewCard.swift
//  Viaplay
//
//  Modular component: Player interview/quote
//  Reusable for any player
//

import SwiftUI

struct PlayerInterviewCard: View {
    let playerName: String
    let playerPhoto: String?
    let quote: String
    let teamName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                // Player photo
                AsyncImage(url: playerPhoto.flatMap(URL.init)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.96, green: 0.08, blue: 0.42), Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Text(String(playerName.prefix(1)))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(playerName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Text("Spillerintervju")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text(teamName)
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
            
            // Quote
            HStack(alignment: .top, spacing: 8) {
                Text("\"")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(red: 0.96, green: 0.08, blue: 0.42))
                    .offset(y: -4)
                
                Text(quote)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.95))
                    .lineSpacing(2)
                
                Spacer()
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
                                    Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.3),
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
    PlayerInterviewCard(
        playerName: "Lamine Yamal",
        playerPhoto: nil,
        quote: "Vi er klare. Dette blir en stor kamp for oss. Vi skal gi alt for fansene.",
        teamName: "Barcelona"
    )
    .padding()
    .background(Color.black)
}
