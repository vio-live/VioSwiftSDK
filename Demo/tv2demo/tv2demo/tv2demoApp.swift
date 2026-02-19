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
        print("✅ [TV2Demo] Vio SDK configured successfully")
        print("🎨 [TV2Demo] Theme: \(VioConfiguration.shared.theme.name)")
        print("🎨 [TV2Demo] Mode: \(VioConfiguration.shared.theme.mode)")
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
