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
            let result = await BroadcastValidationService.validate(contentId: contentId, country: country)
            VioLogger.debug("contentId validation: hasEngagement=\(result.hasEngagement), contentId=\(contentId)", component: "BroadcastContextSetup")

            if !result.hasEngagement {
                VioLogger.debug("No engagement for contentId=\(contentId), skipping", component: "BroadcastContextSetup")
                return
            }

            guard let broadcastId = result.broadcastId else {
                VioLogger.warning("hasEngagement=true but no broadcastId in response", component: "BroadcastContextSetup")
                return
            }

            let broadcastContext = BroadcastContext(
                broadcastId: broadcastId,
                broadcastName: result.broadcastName,
                startTime: nil,
                channelId: nil,
                metadata: nil
            )
            sessionContext.configure(broadcastContext: broadcastContext, useBackendEngagement: true)

            VioLogger.debug("contentId flow: using broadcastId=\(broadcastId)", component: "BroadcastContextSetup")
            if autoDiscover {
                await campaignManager.discoverCampaigns(broadcastId: broadcastId)
            }
            await campaignManager.setBroadcastContext(broadcastContext)
            await EngagementManager.shared.loadEngagement(for: broadcastContext, useBackend: true)
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
