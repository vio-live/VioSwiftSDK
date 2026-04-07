//
//  MatchLineupView.swift
//  ViaCastingUI
//
//  Shows starting XI for both teams.
//  Fetches from Vio backend via LineupService — data sourced from Sportmonks.
//

import SwiftUI
import VioCore

// MARK: - Backend-driven Lineup View

/// Fetches and displays lineup for a broadcast.
/// Usage: MatchLineupView(broadcastId: "real-madrid-vs-barcelona-2025-01-24")
public struct MatchLineupView: View {

    let broadcastId: String

    @StateObject private var service = LineupService.shared

    public init(broadcastId: String) {
        self.broadcastId = broadcastId
    }

    public var body: some View {
        Group {
            switch service.state {
            case .idle:
                Color.clear.onAppear { service.loadLineup(broadcastId: broadcastId) }

            case .loading:
                lineupSkeleton

            case .unavailable(let msg):
                unavailableView(message: msg)

            case .error(let msg):
                unavailableView(message: msg)

            case .loaded(let data):
                loadedView(data: data)
            }
        }
        .onAppear {
            service.loadLineup(broadcastId: broadcastId)
        }
    }

    // MARK: - Loaded State

    private func loadedView(data: MatchLineupResponse) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                if let home = data.home, let away = data.away {
                    HStack(alignment: .top, spacing: 0) {
                        teamColumn(team: home, isHome: true)
                        Divider().background(Color.white.opacity(0.1))
                        teamColumn(team: away, isHome: false)
                    }
                    .padding(.vertical, 12)
                } else {
                    unavailableView(message: "Lineup data incomplete")
                }
            }
        }
        .background(Color(hex: "1B1B25"))
    }

    private func teamColumn(team: LineupTeam, isHome: Bool) -> some View {
        VStack(alignment: isHome ? .leading : .trailing, spacing: 0) {
            // Team header
            HStack(spacing: 8) {
                if !isHome { Spacer() }
                if let logo = team.teamLogo, !logo.isEmpty {
                    AsyncImage(url: URL(string: logo)) { img in
                        img.resizable().scaledToFit()
                    } placeholder: {
                        Circle().fill(Color.white.opacity(0.1))
                    }
                    .frame(width: 24, height: 24)
                }
                VStack(alignment: isHome ? .leading : .trailing, spacing: 2) {
                    Text(team.teamName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    if let formation = team.formation {
                        Text(formation)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                if isHome { Spacer() }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            // Players
            ForEach(team.starters) { player in
                playerRow(player: player, isHome: isHome)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func playerRow(player: LineupPlayer, isHome: Bool) -> some View {
        HStack(spacing: 6) {
            if !isHome { Spacer() }

            // Jersey number
            Text(player.jerseyNumber.map { "\($0)" } ?? "-")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 22, alignment: isHome ? .leading : .trailing)

            // Name
            Text(player.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            // Position emoji
            Text(player.positionEmoji)
                .font(.system(size: 11))

            if isHome { Spacer() }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.02))
    }

    // MARK: - Skeleton

    private var lineupSkeleton: some View {
        HStack(alignment: .top, spacing: 0) {
            skeletonColumn
            Divider().background(Color.white.opacity(0.1))
            skeletonColumn
        }
        .padding(.vertical, 12)
        .background(Color(hex: "1B1B25"))
    }

    private var skeletonColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.08))
                .frame(width: 100, height: 14)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            ForEach(0..<11, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 28)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Unavailable

    private func unavailableView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.2))
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
            Text("Tilgjengelig ~60 min før kampstart")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Color(hex: "1B1B25"))
    }
}
