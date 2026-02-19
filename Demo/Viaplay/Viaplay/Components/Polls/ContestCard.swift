//
//  ContestCard.swift
//  Viaplay
//
//  Molecular component: Contest/giveaway card
//

import SwiftUI
import VioCore

struct ContestCard: View {
    let contestId: String
    let title: String
    let prize: String
    let question: String?
    let drawTime: String?
    let onParticipate: () -> Void
    
    @StateObject private var participationManager = UserParticipationManager.shared
    @State private var showSuccessAnimation = false
    
    private var hasParticipated: Bool {
        participationManager.hasParticipatedInContest(contestId)
    }
    
    init(
        contestId: String = "contest-default",
        title: String = "Vinn en drakt fra ditt favorittlag!",
        prize: String = "Fotballdrakt",
        question: String? = nil,
        drawTime: String? = "Etter kampen",
        onParticipate: @escaping () -> Void = {}
    ) {
        self.contestId = contestId
        self.title = title
        self.prize = prize
        self.question = question
        self.drawTime = drawTime
        self.onParticipate = onParticipate
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                // Avatar with trophy
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.96, green: 0.08, blue: 0.42),
                                    Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(VioConfiguration.shared.effectiveBrandConfiguration.name) Konkurranse")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Text("Premie")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text("Aktiv nå")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
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
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineSpacing(1)
            
            // Question (if provided)
            if let question = question {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spørsmål:")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(question)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.95))
                        .lineSpacing(2)
                }
            }
            
            // Prize
            HStack(spacing: 8) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(red: 0.96, green: 0.08, blue: 0.42))
                
                Text("Premie: \(prize)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            // Draw time countdown
            if let drawTime = drawTime {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                    
                    Text("Trekning: \(drawTime)")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.2))
                )
            }
            
            // Participate button
            Button(action: {
                if !hasParticipated {
                    // Record participation
                    participationManager.recordContestParticipation(contestId: contestId)
                    
                    onParticipate()
                    
                    // Success animation
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        showSuccessAnimation = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            showSuccessAnimation = false
                        }
                    }
                }
            }) {
                HStack(spacing: 6) {
                    if showSuccessAnimation {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                            .transition(.scale.combined(with: .opacity))
                        
                        Text("Deltatt!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                    } else if hasParticipated {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Allerede deltatt")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        Image(systemName: "star.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.white)
                        
                        Text("Delta")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            hasParticipated 
                            ? Color.white.opacity(0.1)
                            : Color(red: 0.96, green: 0.08, blue: 0.42)
                        )
                )
            }
            .disabled(hasParticipated)
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
    VStack(spacing: 16) {
        ContestCard(contestId: "preview-1")
        ContestCard(contestId: "preview-2", onParticipate: {})
    }
    .padding()
    .background(Color.black)
}