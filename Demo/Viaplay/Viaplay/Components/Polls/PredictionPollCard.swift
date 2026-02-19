//
//  PredictionPollCard.swift
//  Viaplay
//
//  Modular component: Match prediction poll
//  Reusable for any match
//

import SwiftUI
import VioCore

struct PredictionPollCard: View {
    let homeTeam: String
    let awayTeam: String
    let onVote: (PredictionOption) -> Void
    
    @State private var selectedOption: PredictionOption?
    @State private var showSuccess = false
    
    enum PredictionOption: String {
        case homeWin = "home"
        case draw = "draw"
        case awayWin = "away"
        
        func displayText(homeTeam: String, awayTeam: String) -> String {
            switch self {
            case .homeWin: return "\(homeTeam) vinner"
            case .draw: return "Uavgjort"
            case .awayWin: return "\(awayTeam) vinner"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange, Color.orange.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "crystal.ball")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(VioConfiguration.shared.effectiveBrandConfiguration.name) Spådom")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Text("Før kampen")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("Spå nå")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
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
            
            // Question
            Text("Spå resultatet av kampen")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            // Options
            VStack(spacing: 8) {
                ForEach([PredictionOption.homeWin, .draw, .awayWin], id: \.self) { option in
                    PredictionOptionButton(
                        text: option.displayText(homeTeam: homeTeam, awayTeam: awayTeam),
                        isSelected: selectedOption == option,
                        showSuccess: showSuccess && selectedOption == option,
                        onTap: {
                            selectedOption = option
                            onVote(option)
                            
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
    }
}

// MARK: - Prediction Option Button

private struct PredictionOptionButton: View {
    let text: String
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
            HStack {
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                
                Spacer()
                
                if showSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected 
                        ? Color.orange.opacity(0.25)
                        : Color.white.opacity(0.08)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected 
                                ? Color.orange.opacity(0.5)
                                : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .scaleEffect(scale)
    }
}

#Preview {
    PredictionPollCard(
        homeTeam: "Barcelona",
        awayTeam: "PSG",
        onVote: { _ in }
    )
    .padding()
    .background(Color.black)
}
