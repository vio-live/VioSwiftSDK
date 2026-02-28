//
//  ContentView.swift
//  Viaplay
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI
import VioUI
import VioCore
// import VioLiveUI
// import VioLiveShow

struct ContentView: View {
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject private var checkoutDraft: CheckoutDraft
    @State private var selectedTab = 0
    @State private var showSportView = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Main app content based on selected tab
                Group {
                    if showSportView {
                        SportView(selectedTab: $selectedTab, showSportView: $showSportView)
                    } else {
                        ViaplayHomeView(selectedTab: $selectedTab, showSportView: $showSportView)
                    }
                }
                .onChange(of: selectedTab) { newValue in
                    if newValue == 1 { // Sport tab
                        if !showSportView {
                            showSportView = true
                        }
                    } else if newValue == 0 { // Home tab
                        showSportView = false
                    }
                }
                
                // Global floating cart indicator - always on top
                VFloatingCartIndicator(
                    customPadding: EdgeInsets(
                        top: 0,
                        leading: 0,
                        bottom: 100,
                        trailing: 16
                    )
                )
                .zIndex(999) // Asegurar que esté por encima de todo (video, overlays, etc.)
            }
            .overlay {
                // Global live stream overlay (Tipio integration)
                LiveStreamGlobalOverlay()
                    .environmentObject(cartManager)
            }
            // Checkout Overlay
            .sheet(isPresented: $cartManager.isCheckoutPresented) {
                VCheckoutOverlay()
                    .environmentObject(cartManager)
                    .environmentObject(checkoutDraft)
            }
            // MARK: - Vio SDK Initialization
            .task {
                await initializeVioSDK()
                await debugVioPing()
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Live Stream Overlay

struct LiveStreamGlobalOverlay: View {
    // @ObservedObject private var liveShowManager = LiveShowManager.shared
    @EnvironmentObject private var cartManager: CartManager
    
    var body: some View {
        ZStack {
            // Full screen LiveShow overlay
            // TODO: Re-enable when VioLiveUI and VioLiveShow modules are properly configured
            // if liveShowManager.isLiveShowVisible {
            //     VLiveShowFullScreenOverlay()
            //         .environmentObject(cartManager)
            // }
        }
    }
}

// MARK: - Diagnostics
extension ContentView {
    private func maskKey(_ key: String) -> String {
        guard !key.isEmpty else { return "(empty)" }
        return String(repeating: "*", count: max(0, key.count - 4)) + key.suffix(4)
    }

    private func resolveBaseURL() -> URL? {
        let urlString = VioConfiguration.shared.environment.graphQLURL
        return URL(string: urlString)
    }

    private func logConfig() {
        let cfg = VioConfiguration.shared
        VioLogger.debug("env=\(cfg.environment.rawValue) base=\(cfg.environment.graphQLURL)", component: "ViaplayDemo")
        VioLogger.debug("apiKey=\(maskKey(cfg.apiKey))", component: "ViaplayDemo")
        VioLogger.debug("market country=\(cfg.marketConfiguration.countryCode) currency=\(cfg.marketConfiguration.currencyCode)", component: "ViaplayDemo")
    }

    private func sdkClient() -> SdkClient? {
        guard let base = resolveBaseURL() else {
            VioLogger.warning("Invalid base URL from configuration", component: "ViaplayDemo")
            return nil
        }
        let key = VioConfiguration.shared.apiKey.isEmpty ? "DEMO_KEY" : VioConfiguration.shared.apiKey
        VioLogger.debug("Creating SdkClient base=\(base.absoluteString) apiKey=\(maskKey(key))", component: "ViaplayDemo")
        return SdkClient(baseUrl: base, apiKey: key)
    }

    private func logRequest(_ name: String, payload: [String: Any]) {
        VioLogger.debug("Request \(name) payload=\(payload)", component: "ViaplayDemo")
    }

    private func logResponse(_ name: String, info: [String: Any]) {
        VioLogger.debug("Response \(name) info=\(info)", component: "ViaplayDemo")
    }

    private func logError(_ name: String, error: Error) {
        if let sdkErr = error as? SdkException {
            VioLogger.warning("\(name) sdk=\(sdkErr.description)", component: "ViaplayDemo")
        } else {
            VioLogger.warning("\(name) msg=\(error.localizedDescription)", component: "ViaplayDemo")
        }
    }

    private func currentCurrency() -> String {
        VioConfiguration.shared.marketConfiguration.currencyCode
    }

    private func currentCountry() -> String {
        VioConfiguration.shared.marketConfiguration.countryCode
    }

    private func initializeVioSDK() async {
        VioLogger.debug("── Step 1: Loading campaigns from backend ──", component: "ViaplayDemo")
        let apiKey = VioConfiguration.shared.campaignConfiguration.apiKey
        let baseURL = VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
        VioLogger.debug("apiKey=\(String(apiKey.suffix(8))) baseURL=\(baseURL)", component: "ViaplayDemo")

        await CampaignManager.shared.initializeCampaign()
        VioLogger.debug("── Step 1 complete: CampaignManager initialized ──", component: "ViaplayDemo")

        VioLogger.debug("── Step 2: Loading campaign config (branding + Commerce key) ──", component: "ViaplayDemo")
        if let config = DynamicConfigurationManager.shared.currentConfig {
            VioLogger.debug("brand.name=\(config.brand?.name ?? "nil") commerce.enabled=\(config.integrations?.commerce?.enabled ?? false)", component: "ViaplayDemo")
        } else {
            VioLogger.warning("No campaign config loaded yet", component: "ViaplayDemo")
        }
    }

    private func debugVioPing() async {
        logConfig()
        guard let sdk = sdkClient() else { return }

        let currency = currentCurrency()
        let country = currentCountry()
        logRequest("sdk.channel.product.get", payload: [
            "currency": currency,
            "imageSize": "large",
            "useCache": false,
            "shippingCountryCode": country
        ])

        do {
            let products = try await sdk.channel.product.get(
                currency: currency,
                imageSize: "large",
                barcodeList: nil,
                categoryIds: nil,
                productIds: nil,
                skuList: nil,
                useCache: false,
                shippingCountryCode: country
            )
            logResponse("sdk.channel.product.get", info: [
                "count": products.count
            ])
        } catch {
            logError("sdk.channel.product.get", error: error)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(CartManager())
        .environmentObject(CheckoutDraft())
}
