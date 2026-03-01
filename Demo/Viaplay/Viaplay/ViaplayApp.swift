//
//  ViaplayApp.swift
//  Viaplay
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI
import CoreData
import VioCore
import VioUI
import VioDesignSystem
import VioCastingUI
import VioEngagementSystem

@main
struct ViaplayApp: App {
    let persistenceController = PersistenceController.shared
    
    // MARK: - Global State Managers
    // These are initialized once and shared across the entire app
    @StateObject private var cartManager = CartManager()
    @StateObject private var checkoutDraft = CheckoutDraft()
    
    init() {
        // Load Vio SDK configuration
        // This reads the vio-config.json file with Viaplay colors and theme
        // Stripe is initialized automatically by the SDK
        print("🚀 [Viaplay] Loading Vio SDK configuration...")
        ConfigurationLoader.loadConfiguration()
        print("✅ [Viaplay] Vio SDK configured successfully")
        print("🎨 [Viaplay] Theme: \(VioConfiguration.shared.theme.name)")
        print("🎨 [Viaplay] Mode: \(VioConfiguration.shared.theme.mode)")

        // Setup cache clearing listener for image cache
        CacheHelper.setupCacheClearingListener()
        
        // Configure demo mode for Engagement System if enabled
        if VioConfiguration.shared.engagementConfiguration.demoMode {
            // Set timeline events provider for DemoEngagementRepository
            DemoEngagementRepository.timelineEventsProvider = {
                TimelineDataGenerator.generateBarcelonaPSGTimeline().map { $0.event }
            }
            
            // Set poll converter closure
            DemoEngagementRepository.pollConverter = { event, context in
                guard let pollEvent = event as? PollTimelineEvent else { return nil }
                // Use broadcastContext from event or fallback to provided context
                let eventContext = pollEvent.broadcastContext ?? context
                
                let now = Date()
                let startTime = Date(timeIntervalSince1970: pollEvent.videoTimestamp)
                
                // Calculate end time based on duration or endTimestamp
                let endTime: Date?
                if let endTimestamp = pollEvent.endTimestamp {
                    endTime = Date(timeIntervalSince1970: endTimestamp)
                } else if let duration = pollEvent.duration {
                    endTime = Date(timeIntervalSince1970: pollEvent.videoTimestamp + duration)
                } else {
                    // Default duration: 5 minutes
                    endTime = Date(timeIntervalSince1970: pollEvent.videoTimestamp + 300)
                }
                
                // Determine if poll is active
                let isActive = endTime == nil || now < endTime!
                
                // Calculate total votes
                let totalVotes = pollEvent.options.reduce(0) { $0 + $1.voteCount }
                
                // Convert options
                let pollOptions = pollEvent.options.map { option in
                    Poll.PollOption(
                        id: option.id,
                        text: option.text,
                        voteCount: option.voteCount,
                        percentage: option.percentage ?? (totalVotes > 0 ? Double(option.voteCount) / Double(totalVotes) * 100.0 : 0.0)
                    )
                }
                
                return Poll(
                    id: pollEvent.id,
                    broadcastId: eventContext.broadcastId,
                    question: pollEvent.question,
                    options: pollOptions,
                    startTime: startTime,
                    endTime: endTime,
                    isActive: isActive,
                    totalVotes: totalVotes,
                    broadcastContext: eventContext
                )
            }
            
            // Set contest converter closure
            DemoEngagementRepository.contestConverter = { event, context in
                guard let contestEvent = event as? CastingContestEvent else { return nil }
                // Use broadcastContext from event or fallback to provided context
                let eventContext = contestEvent.broadcastContext ?? context
                
                let now = Date()
                let startTime = Date(timeIntervalSince1970: contestEvent.videoTimestamp)
                
                // Default duration: 10 minutes for contests
                let endTime = Date(timeIntervalSince1970: contestEvent.videoTimestamp + 600)
                
                // Determine if contest is active
                let isActive = now < endTime
                
                // Map contest type
                let contestType: Contest.ContestType = contestEvent.contestType == .quiz ? .quiz : .giveaway
                
                return Contest(
                    id: contestEvent.id,
                    broadcastId: eventContext.broadcastId,
                    title: contestEvent.title,
                    description: contestEvent.description,
                    prize: contestEvent.prize,
                    contestType: contestType,
                    startTime: startTime,
                    endTime: endTime,
                    isActive: isActive,
                    broadcastContext: eventContext
                )
            }
            
            print("🎮 [Viaplay] Demo mode enabled for Engagement System")
        }

        // ── Vio SDK Initialization — global, once at launch ──
        Task.detached(priority: .userInitiated) {
            let baseURL = VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
            let apiKey = VioConfiguration.shared.apiKey
            print("")
            print("╔══════════════════════════════════════════╗")
            print("║       VIO SDK — INITIALIZATION           ║")
            print("╠══════════════════════════════════════════╣")
            print("║  baseURL: \(baseURL)")
            print("║  apiKey:  ...\(String(apiKey.suffix(8)))")
            print("╚══════════════════════════════════════════╝")
            print("")

            // STEP 1 — Discover active campaigns
            print("⬡ [VioInit] STEP 1 — GET /v1/sdk/campaigns")
            await CampaignManager.shared.discoverCampaigns(broadcastId: nil)
            let count = CampaignManager.shared.activeCampaigns.count
            if count > 0 {
                let campaign = CampaignManager.shared.activeCampaigns.first!
                print("✅ [VioInit] STEP 1 — \(count) campaign(s). id=\(campaign.id) state=\(campaign.currentState)")
            } else {
                print("❌ [VioInit] STEP 1 — No active campaigns. Check apiKey and endDate in dashboard.")
                return
            }

            // STEP 2 — Load campaign config (branding + Commerce key)
            guard let campaignId = CampaignManager.shared.activeCampaigns.first?.id else { return }
            print("⬡ [VioInit] STEP 2 — GET /v1/campaigns/\(campaignId)/config")
            if let config = await DynamicConfigurationManager.shared.loadCampaignConfig(campaignId: campaignId, broadcastId: nil) {
                let brandName = config.brand?.name ?? "nil"
                let logoUrl = config.brand?.logoUrl ?? "nil"
                let commerceEnabled = config.integrations?.commerce?.enabled ?? false
                print("✅ [VioInit] STEP 2 — brand=\(brandName) logoUrl=\(String(logoUrl.prefix(60))) commerce=\(commerceEnabled)")
            } else {
                print("❌ [VioInit] STEP 2 — Failed to load campaign config")
            }

            print("⬡ [VioInit] STEP 3 — WebSocket connects when user opens a stream")
            print("")
            print("╔══════════════════════════════════════════╗")
            print("║  VIO SDK READY ✅                        ║")
            print("╚══════════════════════════════════════════╝")
            print("")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                // Inject managers as environment objects
                // This makes them available to ALL child views via @EnvironmentObject
                .environmentObject(cartManager)
                .environmentObject(checkoutDraft)
        }
    }
}
