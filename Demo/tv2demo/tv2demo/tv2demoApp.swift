//
//  tv2demoApp.swift
//  tv2demo
//
//  Created by Angelo Sepulveda on 02/10/2025.
//

import SwiftUI
import VioCore
import VioUI

@main
struct tv2demoApp: App {
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
        
        let cfg = VioConfiguration.shared
        
        print("✅ [TV2Demo] Vio SDK configured successfully")
        print("🎨 [TV2Demo] Theme: \(cfg.theme.name)")
        print("🎨 [TV2Demo] Mode: \(cfg.theme.mode)")
        print("🎨 [TV2Demo] environment: \(cfg.environment.rawValue)")
        print("🎨 [TV2Demo] GraphQL: \(cfg.environment.graphQLURL)")
        print("🎨 [TV2Demo] REST: \(cfg.campaignConfiguration.restAPIBaseURL)")
        print("🎨 [TV2Demo] WebSocket: \(cfg.wsBaseURL)")
        let campaignId = cfg.liveShowConfiguration.campaignId
        if campaignId > 0 {
            print("🎨 [TV2Demo] campaignId (config): \(campaignId)")
        }
        print("🎨 [TV2Demo] autoDiscover: \(cfg.campaignConfiguration.autoDiscover)")
        if !cfg.liveShowConfiguration.commerceBaseUrl.isEmpty {
            print("🎨 [TV2Demo] Commerce: \(cfg.liveShowConfiguration.commerceBaseUrl)")
        }
        print("🎨 [TV2Demo] apiKey: \(cfg.apiKey.prefix(10))…")
        
        // Set demo userId for WS identify — backend uses this to route cart_intent events
        // In production replace with real user identity (e.g. JWT sub claim)
        CampaignManager.shared.userId = "tv2_demo_user"
        print("👤 [TV2Demo] userId set: tv2_demo_user")
        
        if campaignId > 0 {
            let ws = "\(cfg.wsBaseURL)/ws/\(campaignId)?userId=\(CampaignManager.shared.userId ?? "")"
            print("🎨 [TV2Demo] WebSocket URL: \(ws)")
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
