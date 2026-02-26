//
//  CastingContestCardWrapper.swift
//  Viaplay
//
//  Wrapper component that uses VEngagementContestCard from SDK
//  Converts CastingContestEvent to SDK component format
//

import SwiftUI
import VioCore
import VioEngagementUI
import VioDesignSystem

struct CastingContestCardWrapper: View {
    let contest: CastingContestEvent
    let onParticipate: () -> Void
    
    @State private var showModal = false
    
    var body: some View {
        let brandConfig = VioConfiguration.shared.brandConfiguration
        
        return VEngagementContestCard(
            title: contest.title,
            description: contest.description,
            prize: contest.prize,
            contestType: contest.contestType == .quiz ? "Quiz" : "Konkurranse",
            imageAsset: contest.metadata?["imageAsset"],
            brandName: brandConfig.name,
            brandIcon: brandConfig.iconAsset,
            displayTime: contest.displayTime,
            onParticipate: {
                showModal = true
                onParticipate()
            }
        )
        .sheet(isPresented: $showModal) {
            CastingContestModal(contest: contest) {
                showModal = false
            }
        }
    }
}
