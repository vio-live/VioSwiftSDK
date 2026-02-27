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
