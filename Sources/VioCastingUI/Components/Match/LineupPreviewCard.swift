//
//  LineupPreviewCard.swift
//  VioCastingUI
//
//  Compact lineup preview card for the All feed.
//  Shows starting XI summary for both teams. Tapping opens the full lineup in Statistics tab.
//

import SwiftUI
import VioCore

/// Compact lineup card shown at the top of the All feed.
/// Automatically loads from LineupService using the current broadcast context.
struct LineupPreviewCard: View {

    let onTapFullLineup: () -> Void   // → switch to Statistics tab

    @ObservedObject private var lineupService = LineupService.shared
    @ObservedObject private var campaignManager = CampaignManager.shared

    private var broadcastId: String? {
        campaignManager.currentBroadcastContext?.broadcastId
    }

    var body: some View {
        Group {
            switch lineupService.state {
            case .loaded(let data) where data.home != nil && data.away != nil:
                cardContent(data: data)

            case .unavailable:
                // Don't show card at all if not available yet
                EmptyView()

            case .loading:
                loadingCard

            default:
                EmptyView()
            }
        }
        .onAppear {
            if let bid = broadcastId {
                lineupService.loadLineup(broadcastId: bid)
            }
        }
    }

    // MARK: - Loaded card

    private func cardContent(data: MatchLineupResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Oppstillinger")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Button(action: onTapFullLineup) {
                    HStack(spacing: 4) {
                        Text("Se full")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.96, green: 0.08, blue: 0.42))
                }
            }

            // Two team columns
            HStack(alignment: .top, spacing: 12) {
                if let home = data.home {
                    teamPreviewColumn(team: home, isHome: true)
                }
                Divider()
                    .background(Color.white.opacity(0.1))
                    .frame(height: 110)
                if let away = data.away {
                    teamPreviewColumn(team: away, isHome: false)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func teamPreviewColumn(team: LineupTeam, isHome: Bool) -> some View {
        VStack(alignment: isHome ? .leading : .trailing, spacing: 4) {
            // Team name + formation
            HStack(spacing: 4) {
                if !isHome { Spacer() }
                if let logo = team.teamLogo {
                    AsyncImage(url: URL(string: logo)) { img in
                        img.resizable().scaledToFit()
                    } placeholder: { Color.clear }
                    .frame(width: 16, height: 16)
                }
                Text(team.teamName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if isHome { Spacer() }
            }

            if let formation = team.formation {
                Text(formation)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: isHome ? .leading : .trailing)
            }

            // First 5 players preview
            ForEach(team.starters.prefix(5)) { player in
                HStack(spacing: 4) {
                    if !isHome { Spacer() }
                    Text(player.jerseyNumber.map { "\($0)." } ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                        .frame(width: 18, alignment: isHome ? .leading : .trailing)
                    Text(player.name)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                    if isHome { Spacer() }
                }
            }

            if team.starters.count > 5 {
                Text("+\(team.starters.count - 5) mer")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, alignment: isHome ? .leading : .trailing)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading

    private var loadingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.08)).frame(width: 120, height: 14)
            HStack(spacing: 12) {
                skeletonColumn
                Divider().background(Color.white.opacity(0.1))
                skeletonColumn
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }

    private var skeletonColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<5, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 12)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
