//
//  TimelinePollCard.swift
//  Viaplay
//
//  Molecular component: Poll from timeline (same style as PollCard)
//

import SwiftUI
import VioCore

struct TimelinePollCard: View {
    let poll: PollTimelineEvent
    let onVote: (String) -> Void
    
    @StateObject private var participationManager = UserParticipationManager.shared
    @State private var selectedOption: String?
    @State private var showSuccessAnimation = false
    
    private var hasVoted: Bool {
        participationManager.hasVotedInPoll(poll.id)
    }
    
    private var userVote: String? {
        participationManager.getVote(for: poll.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header (same style as other cards)
            HStack(spacing: 8) {
                // Avatar with initials
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple, Color.purple.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Text("AS")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(VioConfiguration.shared.effectiveBrandConfiguration.name) Avstemning")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Text("Direktesending")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        
                        Text(poll.displayTime)
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
            
            // Question
            Text(poll.question)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(1)
            
            // Options
            VStack(spacing: 8) {
                ForEach(poll.options) { option in
                    PollTimelineOptionButton(
                        option: option,
                        isSelected: userVote == option.id,
                        isDisabled: hasVoted,
                        showSuccess: showSuccessAnimation && selectedOption == option.id,
                        onTap: {
                            selectedOption = option.id
                            
                            // Record participation
                            participationManager.recordPollVote(pollId: poll.id, optionId: option.id)
                            
                            onVote(option.id)
                            
                            // Success animation
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                showSuccessAnimation = true
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showSuccessAnimation = false
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
                                    Color.purple.opacity(0.4),
                                    Color.purple.opacity(0.1)
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

// MARK: - Poll Timeline Option Button

private struct PollTimelineOptionButton: View {
    let option: PollTimelineEvent.PollOption
    let isSelected: Bool
    let isDisabled: Bool
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
                Text(option.text)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
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
                        ? Color.purple.opacity(0.25)
                        : Color.white.opacity(isDisabled ? 0.05 : 0.08)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected 
                                ? Color.purple.opacity(0.5)
                                : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .scaleEffect(scale)
        .disabled(isDisabled)
    }
}

#Preview {
    TimelinePollCard(
        poll: PollTimelineEvent(
            id: "poll-1",
            videoTimestamp: 600,
            question: "Hvem vinner denne kampen?",
            options: [
                .init(id: "opt1", text: "Barcelona", voteCount: 3456, percentage: 65),
                .init(id: "opt2", text: "Real Madrid", voteCount: 1234, percentage: 23)
            ],
            duration: 600,
            endTimestamp: 1200,
            metadata: nil,
            broadcastContext: nil
        ),
        onVote: { _ in }
    )
    .padding()
    .background(Color.black)
}
