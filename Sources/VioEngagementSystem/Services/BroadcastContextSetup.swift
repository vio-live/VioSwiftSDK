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
    
    // Prevent concurrent setup calls
    private static var isSettingUp = false

    /// Sets up broadcast context for a session. Call from .task when view appears.
    /// - Parameters:
    ///   - sessionContext: The session context to configure (mutated in place)
    ///   - fallbackBroadcastContext: Closure to provide BroadcastContext when no contentId (e.g. match.toBroadcastContext)
    public static func setup(
        sessionContext: VioSessionContext,
        fallbackBroadcastContext: () -> BroadcastContext
    ) async {
        // Guard against concurrent calls — SwiftUI can re-render multiple times
        guard !isSettingUp else {
            print("⚠️ [VioInit] BroadcastContextSetup already running, skipping duplicate call")
            return
        }
        isSettingUp = true
        defer { isSettingUp = false }
        
        print("⬡ [VioInit] BroadcastContextSetup.setup — contentId=\(sessionContext.contentId ?? "nil") country=\(sessionContext.country ?? "nil")")

        let config = VioConfiguration.shared
        let autoDiscover = config.campaignConfiguration.autoDiscover
        let campaignManager = CampaignManager.shared

        // ContentId flow: validate before discoverCampaigns/loadEngagement
        if let contentId = sessionContext.contentId, let country = sessionContext.country {
            print("⬡ [VioInit] STEP 3 — GET /v1/sdk/broadcast?contentId=\(contentId)&country=\(country)")
            let result = await BroadcastValidationService.validate(contentId: contentId, country: country)

            if !result.hasEngagement {
                print("⭕ [VioInit] STEP 3 — hasEngagement=false. No overlay shown.")
                return
            }

            guard let broadcastId = result.broadcastId else {
                print("❌ [VioInit] STEP 3 — hasEngagement=true but no broadcastId in response")
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

            print("⬡ [VioInit] STEP 4 — Connecting WebSocket /ws/\(campaignManager.activeCampaigns.first?.id ?? -1)")
            // Skip discoverCampaigns if already done at launch (activeCampaigns already loaded)
            if autoDiscover && campaignManager.activeCampaigns.isEmpty {
                await campaignManager.discoverCampaigns(broadcastId: broadcastId)
            }
            await campaignManager.setBroadcastContext(broadcastContext)

            // Wire WebSocket callbacks for polls/contests (WebSocket-driven engagement)
            campaignManager.setEngagementCallbacks(broadcastId: broadcastId)
            campaignManager.onPollEventReceived = { json, bid in
                guard let broadcastId = bid,
                      let data = json["data"] as? [String: Any],
                      let id = data["id"] as? String,
                      let question = data["question"] as? String,
                      let optionsRaw = data["options"] as? [[String: Any]] else { return }
                let options: [Poll.PollOption] = optionsRaw.compactMap { opt in
                    guard let text = opt["text"] as? String else { return nil }
                    return Poll.PollOption(id: UUID().uuidString, text: text)
                }
                let poll = Poll(id: id, broadcastId: broadcastId, question: question, options: options, isActive: true)
                Task { await EngagementManager.shared.addOrUpdatePoll(poll, broadcastId: broadcastId) }
            }
            campaignManager.onContestEventReceived = { json, bid in
                // Support both flat and nested formats from backend
                let payload = json["data"] as? [String: Any] ?? json
                guard let broadcastId = bid,
                      let id = payload["id"] as? String,
                      let name = payload["name"] as? String ?? payload["title"] as? String else { return }
                let prize = payload["prize"] as? String ?? ""
                let description = payload["description"] as? String ?? ""
                let imageUrl = payload["imageUrl"] as? String
                let contestTypeStr = payload["contestType"] as? String ?? "quiz"
                let contestType: Contest.ContestType = contestTypeStr.lowercased() == "giveaway" ? .giveaway : .quiz
                let contest = Contest(id: id, broadcastId: broadcastId, title: name, description: description, prize: prize, contestType: contestType, imageUrl: imageUrl, isActive: true)
                let imgDebug = imageUrl ?? "nil"
                print("🎯 [VioInit] contest received: id=\(id) broadcastId=\(broadcastId) imageUrl=\(imgDebug)")
                Task { await EngagementManager.shared.addOrUpdateContest(contest, broadcastId: broadcastId) }
            }

            print("⬡ [VioInit] STEP 5 — WebSocket-driven engagement active (no HTTP fetch)")
            print("✅ [VioInit] STEP 5 — Setup complete. Waiting for WS events.")
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
        // await EngagementManager.shared.loadEngagement(for: broadcastContext) // Comentado para debug RAM
    }
}
