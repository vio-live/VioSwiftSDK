//
//  tv2demoApp.swift
//  tv2demo
//
//  Created by Angelo Sepulveda on 02/10/2025.
//

import SwiftUI
import UserNotifications
import VioCore
import VioUI

private enum TV2DemoConsole {
    private static let tag = "\u{1F3AF} [TV2Demo]"
    static func log(_ message: String) {
        print("\(tag) \(message)")
    }
}

@main
struct tv2demoApp: App {
    @UIApplicationDelegateAdaptor(TV2AppDelegate.self) private var appDelegate

    /// Strong reference; `UNUserNotificationCenter` delegate is weak.
    private static let notificationCenterDelegate = TV2NotificationCenterDelegate()
    // MARK: - Global State Managers
    // These are initialized once and shared across the entire app
    @StateObject private var cartManager = CartManager()
    @StateObject private var checkoutDraft = CheckoutDraft()
    
    init() {
        ConfigurationLoader.loadConfiguration()

        let cfg = VioConfiguration.shared
        #if DEBUG
        let rest = cfg.campaignConfiguration.restAPIBaseURL
        let ws = cfg.wsBaseURL
        let keyHint = cfg.apiKey.count >= 10 ? "\(cfg.apiKey.prefix(10))…" : "(short)"
        TV2DemoConsole.log(
            "SDK ready env=\(cfg.environment.rawValue) theme=\(cfg.theme.name) autoDiscover=\(cfg.campaignConfiguration.autoDiscover) | REST \(rest) WS \(ws) apiKey \(keyHint)",
        )
        #else
        TV2DemoConsole.log(
            "SDK ready env=\(cfg.environment.rawValue) theme=\(cfg.theme.name) autoDiscover=\(cfg.campaignConfiguration.autoDiscover)",
        )
        #endif

        CampaignManager.shared.userId = "tv2_demo_user"

        CampaignManager.shared.onCartIntentFromWebSocket = { event, delivery in
            TV2DemoCartIntentLogging.logSocketCartIntent(event, delivery: delivery)
        }

        CampaignManager.shared.showsCartIntentLocalNotificationWhenAppIsActive = false

        UNUserNotificationCenter.current().delegate = Self.notificationCenterDelegate
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
