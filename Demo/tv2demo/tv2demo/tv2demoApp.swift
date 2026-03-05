//
//  tv2demoApp.swift
//  tv2demo
//
//  Created by Angelo Sepulveda on 02/10/2025.
//

import SwiftUI
import VioCore
import VioUI
import VioDesignSystem
import VioCastingUI
import VioEngagementSystem

@main
struct tv2demoApp: App {
    @UIApplicationDelegateAdaptor(VioAppDelegate.self) var appDelegate
    // MARK: - Global State Managers
    // These are initialized once and shared across the entire app
    @StateObject private var cartManager = CartManager()
    @StateObject private var checkoutDraft = CheckoutDraft()
    
    init() {
        // Load Vio SDK configuration
        // This reads the vio-config.json file with TV2 colors and theme
        // Stripe is initialized automatically by the SDK
        print("🚀 [TV2Demo] Loading Vio SDK configuration...")
        ConfigurationLoader.loadConfiguration()
        VioConfiguration.shared.userId = "angelo_demo_001"  // debe coincidir con Apple TV cart-intent
        print("✅ [TV2Demo] Vio SDK configured successfully")
        print("🎨 [TV2Demo] Theme: \(VioConfiguration.shared.theme.name)")
        print("🎨 [TV2Demo] Mode: \(VioConfiguration.shared.theme.mode)")

        // ── Vio SDK Initialization — global, once at launch ──
        Task(priority: .userInitiated) {
            let baseURL = await VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
            let apiKey = await VioConfiguration.shared.apiKey
            print("╔══════════════════════════════════════════╗")
            print("║       VIO SDK — INITIALIZATION           ║")
            print("║  baseURL: \(baseURL)")
            print("║  apiKey:  ...\(String(apiKey.suffix(8)))")
            print("╚══════════════════════════════════════════╝")

            // STEP 1 — Discover active campaigns
            print("⬡ [VioInit] STEP 1 — GET /v1/sdk/campaigns")
            await CampaignManager.shared.discoverCampaigns(broadcastId: nil)
            let count = await CampaignManager.shared.activeCampaigns.count
            if count > 0 {
                let campaign = await CampaignManager.shared.activeCampaigns.first!
                print("✅ [VioInit] STEP 1 — \(count) campaign(s). id=\(campaign.id) state=\(campaign.currentState)")
            } else {
                print("❌ [VioInit] STEP 1 — No active campaigns. Check apiKey and endDate in dashboard.")
                return
            }

            // STEP 2 — Load campaign config (branding + Commerce key)
            guard let campaignId = await CampaignManager.shared.activeCampaigns.first?.id else { return }
            print("⬡ [VioInit] STEP 2 — GET /v1/campaigns/\(campaignId)/config")
            if let config = await DynamicConfigurationManager.shared.loadCampaignConfig(campaignId: campaignId, broadcastId: nil) {
                if let brandConfig = config.brand {
                    VioConfiguration.shared.updateDynamicBrandConfig(brandConfig)
                }
                if let sponsorConfig = config.sponsor {
                    VioConfiguration.shared.updateSponsorConfig(sponsorConfig)
                }
                if let commerceConfig = config.integrations?.commerce {
                    VioConfiguration.shared.updateDynamicCommerceConfig(commerceConfig)
                }
                let brandName = config.brand?.name ?? "nil"
                let logoUrl = config.brand?.logoUrl ?? config.sponsor?.logoUrl ?? "nil"
                let commerceEnabled = config.integrations?.commerce?.enabled ?? false
                print("✅ [VioInit] STEP 2 — brand=\(brandName) logoUrl=\(String(logoUrl.prefix(60))) commerce=\(commerceEnabled)")
            } else {
                print("❌ [VioInit] STEP 2 — Failed to load campaign config")
            }
            print("║  VIO SDK READY ✅")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                // Inject managers as environment objects
                // This makes them available to ALL child views via @EnvironmentObject
                .environmentObject(cartManager)
                .environmentObject(checkoutDraft)
        }
    }
}
