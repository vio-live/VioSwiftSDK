//
//  BroadcastContextSetup.swift
//  VioEngagementSystem
//
//  Shared setup for broadcast context: contentId validation and engagement loading.
//  Used by LiveMatchView, VCastingVideoPlayer, VCastingActiveView.
//

import Foundation
import VioCore

/// Orchestrates broadcast context setup for contentId flow and legacy flow.
/// Validates via GET /v1/sdk/broadcast when contentId + country are set.
@MainActor
public enum BroadcastContextSetup {

    /// Sets up broadcast context for a session. Call from .task when view appears.
    /// - Parameters:
    ///   - sessionContext: The session context to configure (mutated in place)
    ///   - fallbackBroadcastContext: Closure to provide BroadcastContext when no contentId (e.g. match.toBroadcastContext)
    public static func setup(
        sessionContext: VioSessionContext,
        fallbackBroadcastContext: () -> BroadcastContext
    ) async {
        let config = VioConfiguration.shared
        let autoDiscover = config.campaignConfiguration.autoDiscover
        let campaignManager = CampaignManager.shared

        // ContentId flow: validate before discoverCampaigns/loadEngagement
        if let contentId = sessionContext.contentId, let country = sessionContext.country {
            VioLogger.debug("⬡ STEP 3 — GET /v1/sdk/broadcast?contentId=\(contentId)&country=\(country)", component: "VioInit")
            let result = await BroadcastValidationService.validate(contentId: contentId, country: country)

            if !result.hasEngagement {
                VioLogger.debug("⭕ STEP 3 — hasEngagement=false for contentId=\(contentId). No overlay shown.", component: "VioInit")
                return
            }

            guard let broadcastId = result.broadcastId else {
                VioLogger.warning("❌ STEP 3 — hasEngagement=true but no broadcastId in response", component: "VioInit")
                return
            }

            VioLogger.debug("✅ STEP 3 — hasEngagement=true broadcastId=\(broadcastId) status=\(result.status ?? "unknown")", component: "VioInit")

            let broadcastContext = BroadcastContext(
                broadcastId: broadcastId,
                broadcastName: result.broadcastName,
                startTime: nil,
                channelId: nil,
                metadata: nil
            )
            sessionContext.configure(broadcastContext: broadcastContext, useBackendEngagement: true)

            VioLogger.debug("⬡ STEP 4 — Connecting WebSocket /ws/\(campaignManager.activeCampaigns.first?.id ?? -1)", component: "VioInit")
            if autoDiscover {
                await campaignManager.discoverCampaigns(broadcastId: broadcastId)
            }
            await campaignManager.setBroadcastContext(broadcastContext)

            VioLogger.debug("⬡ STEP 5 — Loading engagement (polls, contests, chat)", component: "VioInit")
            await EngagementManager.shared.loadEngagement(for: broadcastContext, useBackend: true)
            VioLogger.debug("✅ STEP 5 — Engagement loaded. Overlay should be visible.", component: "VioInit")
            return
        }

        // Legacy flow: broadcastContext from session or fallback
        let broadcastContext: BroadcastContext
        if let ctx = sessionContext.broadcastContext {
            broadcastContext = ctx
        } else {
            broadcastContext = fallbackBroadcastContext()
            sessionContext.configure(broadcastContext: broadcastContext)
        }

        if autoDiscover {
            await campaignManager.discoverCampaigns(broadcastId: broadcastContext.broadcastId)
            await campaignManager.setBroadcastContext(broadcastContext)
        } else {
            await campaignManager.setBroadcastContext(broadcastContext)
        }
        await EngagementManager.shared.loadEngagement(for: broadcastContext)
    }
}
