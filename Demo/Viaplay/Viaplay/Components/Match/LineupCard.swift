//
//  LineupCard.swift
//  Viaplay
//
//  Modular component: Team lineup display
//  Reusable for any team, any match
//

import SwiftUI
import VioCore

struct LineupCard: View {
    let teamName: String
    let formation: String
    let players: [PlayerInfo]
    let teamColor: Color
    let isHome: Bool
    
    @StateObject private var campaignManager = CampaignManager.shared
    @State private var showFieldView = true  // Default to field view
    @State private var reactionCounts: [String: Int]
    @State private var userReactions: Set<String> = []
    @State private var animatingReaction: String?
    
    init(
        teamName: String,
        formation: String,
        players: [PlayerInfo],
        teamColor: Color = .blue,
        isHome: Bool = true
    ) {
        self.teamName = teamName
        self.formation = formation
        self.players = players
        self.teamColor = teamColor
        self.isHome = isHome
        
        // Initialize reactions
        _reactionCounts = State(initialValue: [
            "🔥": Int.random(in: 200...400),
            "❤️": Int.random(in: 150...300),
            "⚽": Int.random(in: 250...450),
            "🏆": Int.random(in: 100...250),
            "👍": Int.random(in: 180...350),
            "🎯": Int.random(in: 80...200)
        ])
    }
    
    // MARK: - Position Mapping Helper
    
    private func fieldPosition(from positionString: String) -> FieldPlayer.PlayerPosition {
        let lower = positionString.lowercased()
        if lower.contains("keeper") || lower.contains("målvakt") {
            return .goalkeeper
        } else if lower.contains("forsvar") || lower.contains("defen") {
            return .defender
        } else if lower.contains("midtbane") || lower.contains("mid") {
            return .midfielder
        } else {
            return .forward
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header (Viaplay avatar, not team)
            HStack(spacing: 8) {
                // Viaplay icon
                Image(DemoDataManager.shared.brandAsset(for: .icon))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("\(VioConfiguration.shared.effectiveBrandConfiguration.name) Oppstilling")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                    }
                    
                    HStack(spacing: 4) {
                        Text(teamName)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("\(formation)")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Sponsor - Campaign logo from CampaignManager
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Sponset av")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    
                    // Campaign logo from CampaignManager
                    if let logoUrl = campaignManager.currentCampaign?.campaignLogo, let url = URL(string: logoUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: 50, maxHeight: 16)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 50, maxHeight: 16)
                            case .failure:
                                Image(DemoDataManager.shared.defaultLogo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 50, maxHeight: 16)
                            @unknown default:
                                Image(DemoDataManager.shared.defaultLogo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 50, maxHeight: 16)
                            }
                        }
                    } else {
                        // Fallback to hardcoded logo if no campaign logo
                        Image(DemoDataManager.shared.defaultLogo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 50, maxHeight: 16)
                    }
                }
            }
            
            // Toggle between field and list view
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showFieldView.toggle()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: showFieldView ? "list.bullet" : "field.of.play.soccer")
                        .font(.system(size: 11))
                    Text(showFieldView ? "Liste" : "Felt")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            
            if showFieldView {
                // Field visualization
                FootballFieldView(
                    formation: formation,
                    players: players.map { playerInfo in
                        FieldPlayer(
                            number: playerInfo.number,
                            name: playerInfo.name,
                            shortName: playerInfo.name,
                            position: fieldPosition(from: playerInfo.position)
                        )
                    },
                    teamColor: teamColor
                )
                .frame(maxWidth: .infinity)  // Use full width
                .frame(height: 300)  // Smaller height for half field
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            } else {
                // List view (original)
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(players.prefix(11), id: \.number) { player in
                        PlayerRow(player: player, teamColor: teamColor)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            // Reactions (same as tweets/highlights)
            HStack(spacing: 8) {
                ForEach(["🔥", "❤️", "⚽", "🏆", "👍", "🎯"], id: \.self) { emoji in
                    CompactReactionButton(
                        emoji: emoji,
                        count: reactionCounts[emoji] ?? 0,
                        isSelected: userReactions.contains(emoji),
                        isAnimating: animatingReaction == emoji,
                        onTap: {
                            handleReaction(emoji)
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
                                    teamColor.opacity(0.4),
                                    teamColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    // MARK: - Reaction Handling
    
    private func handleReaction(_ emoji: String) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if userReactions.contains(emoji) {
                userReactions.remove(emoji)
                reactionCounts[emoji, default: 0] -= 1
            } else {
                userReactions.insert(emoji)
                reactionCounts[emoji, default: 0] += 1
                
                animatingReaction = emoji
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    animatingReaction = nil
                }
            }
        }
    }
}

// MARK: - Player Row

private struct PlayerRow: View {
    let player: PlayerInfo
    let teamColor: Color
    
    var body: some View {
        HStack(spacing: 6) {
            // Number badge
            Text("\(player.number)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(teamColor.opacity(0.3)))
            
            // Player name
            Text(player.name)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Compact Reaction Button (same as tweets)

private struct CompactReactionButton: View {
    let emoji: String
    let count: Int
    let isSelected: Bool
    let isAnimating: Bool
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return "\(count)"
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                scale = 0.9
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.0
                }
            }
            onTap()
        }) {
            HStack(spacing: 2) {
                Text(emoji)
                    .font(.system(size: 12))
                    .scaleEffect(isAnimating ? 1.15 : 1.0)
                
                Text(formatCount(count))
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.65))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(
                        isSelected 
                        ? Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.25)
                        : Color.white.opacity(0.06)
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected 
                                ? Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.4)
                                : Color.clear,
                                lineWidth: 0.5
                            )
                    )
            )
        }
        .scaleEffect(scale)
    }
}

// MARK: - Player Info Model

struct PlayerInfo: Identifiable {
    let id = UUID()
    let number: Int
    let name: String
    let position: String  // "Keeper", "Forsvar", "Midtbane", "Angrep"
}

#Preview {
    VStack(spacing: 16) {
        LineupCard(
            teamName: "FC Barcelona",
            formation: "4-3-3",
            players: [
                PlayerInfo(number: 1, name: "Ter Stegen", position: "Keeper"),
                PlayerInfo(number: 2, name: "Koundé", position: "Forsvar"),
                PlayerInfo(number: 3, name: "Araújo", position: "Forsvar"),
                PlayerInfo(number: 4, name: "Christensen", position: "Forsvar"),
                PlayerInfo(number: 18, name: "Alba", position: "Forsvar"),
                PlayerInfo(number: 5, name: "Busquets", position: "Midtbane"),
                PlayerInfo(number: 21, name: "De Jong", position: "Midtbane"),
                PlayerInfo(number: 8, name: "Pedri", position: "Midtbane"),
                PlayerInfo(number: 10, name: "Dembélé", position: "Angrep"),
                PlayerInfo(number: 9, name: "Lewandowski", position: "Angrep"),
                PlayerInfo(number: 7, name: "Ferran", position: "Angrep")
            ],
            teamColor: .blue,
            isHome: true
        )
    }
    .padding()
    .background(Color.black)
}
