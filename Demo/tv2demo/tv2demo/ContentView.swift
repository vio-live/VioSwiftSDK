//
//  ContentView.swift
//  tv2demo
//
//  Created by Angelo Sepulveda on 02/10/2025.
//

import SwiftUI
import VioUI
import VioCore
// import VioLiveUI  // Not available as package product
// import VioLiveShow  // Not available as package product
import AVFoundation
import UserNotifications
import Combine

struct ContentView: View {
    @StateObject private var castingManager = CastingManager.shared
    @StateObject private var pushNav = PushNavigationManager.shared
    @State private var showCastingView = false
    @EnvironmentObject var cartManager: CartManager
    @State private var pushProduct: Product? = nil
    @State private var showPushOverlay = false
    
    var body: some View {
        ZStack {
            // Main app content
            HomeView()
            
            // Mini player de casting - SIEMPRE visible cuando hay casting (persistente)
            if castingManager.isCasting {
                CastingMiniPlayer {
                    showCastingView = true
                }
                .zIndex(998) // Por debajo del cart (999) pero por encima del resto
            }
            
            // Global floating cart indicator - always on top
            VFloatingCartIndicator(
                customPadding: EdgeInsets(
                    top: 0,
                    leading: 0,
                    bottom: castingManager.isCasting ? 180 : 100, // Más arriba si hay casting
                    trailing: TV2Theme.Spacing.md
                )
            )
            .zIndex(999) // Asegurar que esté por encima de todo (video, overlays, etc.)
        }
        .fullScreenCover(isPresented: $showCastingView) {
            if castingManager.isCasting {
                CastingActiveView(match: TV2Match.barcelonaPSG)
                    .environmentObject(cartManager)
        .sheet(isPresented: $showPushOverlay) {
            if let product = pushProduct {
                PushProductSheet(product: product, onDismiss: { showPushOverlay = false })
                    .environmentObject(cartManager)
            }
        }
        // DEBUG: botón para simular push sin Apple TV
        .overlay(alignment: .topTrailing) {
            Button("🛒 Demo") {
                Task {
                    await VioSDK.openProduct(id: "408898")
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.6))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .padding()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vioOpenProductOverlay)) { notification in
            if let product = notification.userInfo?["product"] as? Product {
                print("📲 [TV2Demo] Overlay abriendo: \(product.title)")
                pushProduct = product
                showPushOverlay = true
            }
        }

        .onAppear {
            // Verificar si hay un producto pendiente por push notification
            if let productId = PushNavigationManager.shared.consume() {
                print("📲 [TV2Demo] onAppear: productId pendiente \(productId) — abriendo cuando SDK listo...")
                Task {
                    for _ in 0..<20 {
                        if VioConfiguration.shared.shouldUseSDK {
                            break
                        }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                    print("📲 [TV2Demo] SDK listo — openProduct(\(productId))")
                    await VioSDK.openProduct(id: productId)
                }
            }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                print("🔔 [TV2Push] Push auth: granted=\(granted), error=\(String(describing: error))")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("📲 [TV2Push] registerForRemoteNotifications llamado desde ContentView")
                }
            }
        }
            }
        }
        .onChange(of: castingManager.isCasting) { isCasting in
            if !isCasting {
                showCastingView = false
            }
        }
        .overlay {
            // Global live stream overlay (Tipio integration)
            LiveStreamGlobalOverlay()
                .environmentObject(cartManager)
        .sheet(isPresented: $showPushOverlay) {
            if let product = pushProduct {
                PushProductSheet(product: product, onDismiss: { showPushOverlay = false })
                    .environmentObject(cartManager)
            }
        }
        // DEBUG: botón para simular push sin Apple TV
        .overlay(alignment: .topTrailing) {
            Button("🛒 Demo") {
                Task {
                    await VioSDK.openProduct(id: "408898")
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.6))
            .foregroundColor(.white)
            .clipShape(Capsule())
            .padding()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vioOpenProductOverlay)) { notification in
            if let product = notification.userInfo?["product"] as? Product {
                print("📲 [TV2Demo] Overlay abriendo: \(product.title)")
                pushProduct = product
                showPushOverlay = true
            }
        }

        .onAppear {
            // Verificar si hay un producto pendiente por push notification
            if let productId = PushNavigationManager.shared.consume() {
                print("📲 [TV2Demo] onAppear: productId pendiente \(productId) — abriendo cuando SDK listo...")
                Task {
                    for _ in 0..<20 {
                        if VioConfiguration.shared.shouldUseSDK {
                            break
                        }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                    }
                    print("📲 [TV2Demo] SDK listo — openProduct(\(productId))")
                    await VioSDK.openProduct(id: productId)
                }
            }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                print("🔔 [TV2Push] Push auth: granted=\(granted), error=\(String(describing: error))")
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("📲 [TV2Push] registerForRemoteNotifications llamado desde ContentView")
                }
            }
        }
        }
    }
}

// MARK: - Live Stream Overlay

struct LiveStreamGlobalOverlay: View {
    @EnvironmentObject private var cartManager: CartManager
    
    var body: some View {
        // LiveShow modules not available — casting demo uses LiveMatchView instead
        EmptyView()
    }
}

#Preview {
    ContentView()
        .environmentObject(CartManager())
}
