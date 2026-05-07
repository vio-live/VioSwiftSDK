//
//  VgApp.swift
//  Vg
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI
import CoreData
import VioCore
import VioUI
// TODO: Add VioCore package dependency in Xcode
// import VioCore

@main
struct VgApp: App {
    let persistenceController = PersistenceController.shared

    @StateObject private var cartManager = CartManager()
    @StateObject private var checkoutDraft = CheckoutDraft()
    
    init() {
        print("🚀 [VG] Loading Vio SDK configuration...")
        ConfigurationLoader.loadConfiguration()
        print("✅ [VG] Vio SDK configured successfully")
        print("🎨 [VG] Theme: \(VioConfiguration.shared.theme.name)")
        print("🎨 [VG] Mode: \(VioConfiguration.shared.theme.mode)")

        // MARK: - Vio Diagnostic Logs
        let cfg = VioConfiguration.shared
        let apiKeyMasked = cfg.apiKey.isEmpty ? "(empty)" : String(repeating: "*", count: max(0, cfg.apiKey.count - 4)) + cfg.apiKey.suffix(4)
        print("🔧 [Vio][Config] environment=\(cfg.environment.rawValue)")
        print("🔧 [Vio][Config] graphQLURL=\(cfg.environment.graphQLURL)")
        print("🔧 [Vio][Config] apiKey=\(apiKeyMasked)")
        print("🔧 [Vio][Market] country=\(cfg.marketConfiguration.countryCode) currency=\(cfg.marketConfiguration.currencyCode)")

        // Mirror tv2demoApp setup (which has Apple Pay working end-to-end):
        // 1. Pin a stable userId so the SDK's WS identify message has a
        //    sender id. Without it, identify is sent with empty userId
        //    and the server-side cart/payment routing can stall.
        // 2. Register the placement locations the app actually renders
        //    so the manifest upload (POST /v2/mobile/components/manifest)
        //    publishes them. Without this, the manifest is empty and
        //    some downstream flows (including post-bootstrap reconcile
        //    on payment tap) can short-circuit / hang.
        CampaignManager.shared.userId = "demo_user_001"
        print("👤 [VG] userId set: demo_user_001")

        VgPlacementRegistration.registerAll()
        print("📍 [VG] Placement locations registered (home_top, product_spotlight, home_store)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Force light color scheme so SDK overlays
                // (VProductDetailOverlay, VApplePayConfirmationSheet, etc.)
                // pick the white palette via VioColors.adaptive(for:).
                // The news feed + advertorial use explicit hardcoded colors
                // (VGTheme.Colors.burgundy / Color.white) and are unaffected.
                .preferredColorScheme(.light)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                // Inject managers as environment objects
                // This makes them available to ALL child views via @EnvironmentObject
                .environmentObject(cartManager)
                .environmentObject(checkoutDraft)
        }
    }
}
