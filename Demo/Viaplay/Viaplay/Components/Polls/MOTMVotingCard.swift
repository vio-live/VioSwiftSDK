//
//  MOTMVotingCard.swift
//  Viaplay
//
//  Modular component: Man of the Match voting
//  Reusable for any match
//

import SwiftUI

struct MOTMVotingCard: View {
    let topPlayers: [PlayerCandidate]
    let onVote: (String) -> Void
    
    @State private var selectedPlayer: String?
    @State private var showSuccess = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.yellow, Color.yellow.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kampens Spiller")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Text("Avstemning")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("Stem nå")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
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
            
            // Title
            Text("Hvem var kampens beste spiller?")
                .font(.system(size: 14))
                .foregroundColor(.white)
            
            // Player options
            VStack(spacing: 8) {
                ForEach(topPlayers, id: \.name) { player in
                    MOTMPlayerButton(
                        player: player,
                        isSelected: selectedPlayer == player.name,
                        showSuccess: showSuccess && selectedPlayer == player.name,
                        onTap: {
                            selectedPlayer = player.name
                            onVote(player.name)
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                showSuccess = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showSuccess = false
                                }
                            }
                        }
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
                                    Color.yellow.opacity(0.4),
                                    Color.yellow.opacity(0.1)
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

// MARK: - MOTM Player Button

private struct MOTMPlayerButton: View {
    let player: PlayerCandidate
    let isSelected: Bool
    let showSuccess: Bool
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                scale = 0.97
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.0
                }
            }
            onTap()
        }) {
            HStack(spacing: 10) {
                // Player photo
                AsyncImage(url: player.photo.flatMap(URL.init)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .overlay(
                            Text(String(player.name.prefix(1)))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(player.stats)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected 
                        ? Color.yellow.opacity(0.25)
                        : Color.white.opacity(0.08)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected 
                                ? Color.yellow.opacity(0.5)
                                : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .scaleEffect(scale)
    }
}

// MARK: - Player Candidate Model

struct PlayerCandidate {
    let name: String
    let photo: String?
    let stats: String  // e.g. "2 mål, 1 assist"
}

#Preview {
    MOTMVotingCard(
        topPlayers: [
            PlayerCandidate(name: "A. Diallo", photo: nil, stats: "2 mål, 1 assist"),
            PlayerCandidate(name: "Bruno Fernandes", photo: nil, stats: "3 assist"),
            PlayerCandidate(name: "Ter Stegen", photo: nil, stats: "5 redninger")
        ],
        onVote: { _ in }
    )
    .padding()
    .background(Color.black)
}
