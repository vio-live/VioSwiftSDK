//
//  BackendEngagementTabView.swift
//  VioCastingUI
//
//  Engagement tab content when useBackendEngagement is true (contentId flow).
//  Generic for any live event type - displays polls and contests from EngagementManager (backend API).
//

import SwiftUI
import VioCore
import VioDesignSystem
import VioEngagementSystem

struct BackendEngagementTabView: View {
    @ObservedObject var sessionContext: VioSessionContext
    @ObservedObject private var engagementManager = EngagementManager.shared

    private var broadcastId: String? {
        sessionContext.broadcastContext?.broadcastId
    }

    private var polls: [Poll] {
        guard let id = broadcastId else { return [] }
        return engagementManager.pollsByBroadcast[id] ?? []
    }

    private var contests: [Contest] {
        guard let id = broadcastId else { return [] }
        return engagementManager.contestsByBroadcast[id] ?? []
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Engagement")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Text("\(polls.count + contests.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Contests
                ForEach(contests) { contest in
                    ContestCard(
                        contestId: contest.id,
                        title: contest.title,
                        prize: contest.prize,
                        onParticipate: {
                            Task {
                                guard let ctx = sessionContext.broadcastContext else { return }
                                try? await engagementManager.participateInContest(
                                    contestId: contest.id,
                                    broadcastContext: ctx,
                                    userId: sessionContext.userId
                                )
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                }

                // Polls
                ForEach(polls) { poll in
                    BackendPollCard(
                        poll: poll,
                        engagementManager: engagementManager,
                        broadcastContext: sessionContext.broadcastContext,
                        userId: sessionContext.userId
                    )
                    .padding(.horizontal, 16)
                }

                // Empty state
                if polls.isEmpty && contests.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))

                        Text("Ingen engagement ennå")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                }

                Color.clear.frame(height: 1)
            }
            .padding(.vertical, 12)
        }
        .background(Color(hex: "1B1B25"))
    }
}

// MARK: - Backend Poll Card

private struct BackendPollCard: View {
    let poll: Poll
    @ObservedObject var engagementManager: EngagementManager
    let broadcastContext: BroadcastContext?
    let userId: String?

    @State private var selectedOption: String?
    @State private var hasVoted = false
    @State private var isVoting = false

    private var hasVotedInPoll: Bool {
        engagementManager.hasVotedInPoll(poll.id) || hasVoted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
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

                    Text("Direktesending")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()
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
                    Button(action: {
                        guard !hasVotedInPoll, !isVoting, let ctx = broadcastContext else { return }
                        selectedOption = option.id
                        hasVoted = true
                        isVoting = true

                        Task {
                            try? await engagementManager.voteInPoll(
                                pollId: poll.id,
                                optionId: option.id,
                                broadcastContext: ctx,
                                userId: userId
                            )
                            await MainActor.run { isVoting = false }
                        }
                    }) {
                        HStack {
                            Text(option.text)
                                .font(.system(size: 13))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            if selectedOption == option.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(red: 0.96, green: 0.08, blue: 0.42))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    selectedOption == option.id
                                        ? Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.3)
                                        : Color.white.opacity(0.08)
                                )
                        )
                    }
                    .disabled(hasVotedInPoll || isVoting)
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
                                colors: [Color.purple.opacity(0.4), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}
