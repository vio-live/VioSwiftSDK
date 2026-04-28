import SwiftUI
import VioCore
import VioDesignSystem

#if os(iOS)
import UIKit
#endif

/// Dynamic Offer Banner component that receives configuration from backend.
///
/// Two ways to mount:
///
/// **Host-driven** — caller passes the config explicitly (used by hosts
/// that resolve the banner from their own state, e.g. the demo's
/// `componentManager.activeBanner` legacy path):
/// ```swift
/// VOfferBanner(config: bannerConfig)
/// ```
///
/// **Campaign-driven (Sprint 2026-04-28 PM Phase 2)** — caller provides
/// only the placement slot; the SDK resolves the active component via
/// `CampaignManager.getActiveComponent(type:"offer_banner", locationId:)`
/// and renders nothing when no operator binding exists. Live updates
/// (pause/resume/config edit/sponsor swap) flow through the same
/// placement_* WS events the rest of the placement system uses.
/// ```swift
/// VOfferBanner(locationId: "home_offer", onNavigateToStore: { … })
/// ```
public struct VOfferBanner: View {
    /// Host-passed config (mode 1). Nil when in campaign-driven mode.
    private let storedConfig: OfferBannerConfig?
    /// Slot lookup keys (mode 2). Both nil when in host-driven mode.
    private let resolvedComponentId: String?
    private let resolvedLocationId: String?

    /// Observed for campaign-driven mode — when activeComponents
    /// changes (pause / resume / customConfig edit / sponsor swap)
    /// the body re-evaluates and `effectiveConfig` picks up the new
    /// shape. Harmless overhead in host-driven mode (no re-renders
    /// triggered because effectiveConfig still returns storedConfig).
    @ObservedObject private var campaignManager = CampaignManager.shared

    // Optional parameters to override config values
    let customDeeplink: String?
    let customHeight: CGFloat?
    let customTitleFontSize: CGFloat?
    let customSubtitleFontSize: CGFloat?
    let customBadgeFontSize: CGFloat?
    let customButtonFontSize: CGFloat?
    let onNavigateToStore: (() -> Void)? // Callback to navigate to VProductStore

    @State private var timeRemaining: DateComponents?
    @State private var timer: Timer?
    @State private var isImageLoaded = false
    @State private var isLogoLoaded = false
    @State private var countdownEndDate: Date? // Store parsed date
    @State private var timerId: UUID = UUID() // Unique identifier for current timer

    @SwiftUI.Environment(\.colorScheme) private var colorScheme: SwiftUI.ColorScheme

    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }

    /// Resolved config — explicit one wins, then falls back to a
    /// CampaignManager lookup by `(type, componentId, locationId)`.
    /// Returns nil when no operator binding matches in campaign-driven
    /// mode. The body uses this to short-circuit to EmptyView so the
    /// helpers below can keep referencing `config` as a non-optional.
    private var effectiveConfig: OfferBannerConfig? {
        if let stored = storedConfig { return stored }
        guard let component = campaignManager.getActiveComponent(
            type: "offer_banner",
            componentId: resolvedComponentId,
            locationId: resolvedLocationId
        ),
              case .offerBanner(let cfg) = component.config else {
            return nil
        }
        return cfg
    }

    /// Computed `config` for the helpers below. Force-unwraps
    /// `effectiveConfig` — only safe because the body's outer Group
    /// early-outs to EmptyView when effectiveConfig is nil, meaning
    /// none of the helpers run while config could be missing.
    private var config: OfferBannerConfig {
        effectiveConfig ?? OfferBannerConfig.placeholder
    }

    /// Initialize with full config (original method) — host-driven mode.
    public init(config: OfferBannerConfig) {
        self.storedConfig = config
        self.resolvedComponentId = nil
        self.resolvedLocationId = nil
        self.customDeeplink = nil
        self.customHeight = nil
        self.customTitleFontSize = nil
        self.customSubtitleFontSize = nil
        self.customBadgeFontSize = nil
        self.customButtonFontSize = nil
        self.onNavigateToStore = nil
    }

    /// Initialize with config and optional custom parameters — host-driven mode.
    public init(
        config: OfferBannerConfig,
        deeplink: String? = nil,
        height: CGFloat? = nil,
        titleFontSize: CGFloat? = nil,
        subtitleFontSize: CGFloat? = nil,
        badgeFontSize: CGFloat? = nil,
        buttonFontSize: CGFloat? = nil,
        onNavigateToStore: (() -> Void)? = nil
    ) {
        self.storedConfig = config
        self.resolvedComponentId = nil
        self.resolvedLocationId = nil
        self.customDeeplink = deeplink
        self.customHeight = height
        self.customTitleFontSize = titleFontSize
        self.customSubtitleFontSize = subtitleFontSize
        self.customBadgeFontSize = badgeFontSize
        self.customButtonFontSize = buttonFontSize
        self.onNavigateToStore = onNavigateToStore
    }

    /// Campaign-driven init — resolve the active offer_banner
    /// component from CampaignManager via `(componentId, locationId)`.
    /// Renders nothing until the operator binds a campaign_component
    /// to the slot. Sprint 2026-04-28 PM Phase 2.
    public init(
        componentId: String? = nil,
        locationId: String? = nil,
        height: CGFloat? = nil,
        onNavigateToStore: (() -> Void)? = nil
    ) {
        self.storedConfig = nil
        self.resolvedComponentId = componentId
        self.resolvedLocationId = locationId
        self.customDeeplink = nil
        self.customHeight = height
        self.customTitleFontSize = nil
        self.customSubtitleFontSize = nil
        self.customBadgeFontSize = nil
        self.customButtonFontSize = nil
        self.onNavigateToStore = onNavigateToStore
    }
    
    public var body: some View {
        // Campaign-driven mode renders nothing until the operator binds
        // an offer_banner component to the requested slot. Host-driven
        // mode never hits this branch because storedConfig is non-nil.
        Group {
            if effectiveConfig != nil {
                bannerContent
            } else {
                EmptyView()
            }
        }
    }

    /// The actual banner content — extracted so the outer body can
    /// short-circuit to EmptyView when no config resolves. All helpers
    /// reference `self.config` (computed) which falls back to a safe
    /// placeholder when nil; that fallback never actually renders
    /// because this view isn't constructed in the nil case.
    private var bannerContent: some View {
        ZStack {
            // Background layer - debe estar primero y ocupar todo el espacio
            backgroundLayer
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all, edges: [])
            
            // Content in two columns (same layout as hardcoded banner)
            // Solo mostrar contenido cuando la imagen esté cargada
            if isImageLoaded {
                HStack(alignment: .center, spacing: 16) {
                    // Left column: Logo, title, subtitle, countdown
                    VStack(alignment: .leading, spacing: 4) {
                        // Logo
                        logoImageView
                        
                        // Title - always show if configuration exists
                        Text(config.title)
                            .font(.system(size: customTitleFontSize ?? 24, weight: .bold))
                            .foregroundColor(adaptiveColors.surface)
                        
                        // Subtitle
                        if let subtitle = config.subtitle {
                            Text(subtitle)
                                .font(.system(size: customSubtitleFontSize ?? 11, weight: .regular))
                                .foregroundColor(adaptiveColors.surface.opacity(0.9))
                        }
                        
                        // Countdown (analog style like hardcoded banner)
                        if let remaining = timeRemaining {
                            analogCountdown(timeRemaining: remaining)
                        }
                    }
                    
                    Spacer()
                    
                    // Right column: Discount badge + Button (centered vertically)
                    VStack(spacing: 8) {
                        // Discount badge
                        Text(config.discountBadgeText)
                            .font(.system(size: customBadgeFontSize ?? 18, weight: .bold))
                            .foregroundColor(adaptiveColors.surface)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(adaptiveColors.textPrimary.opacity(0.8))
                            )
                        
                        // Button
                        Button(action: {
                            handleCTAAction()
                        }) {
                            HStack(spacing: 6) {
                                Text(config.ctaText)
                                    .font(.system(size: customButtonFontSize ?? 12, weight: .semibold))
                                    .foregroundColor(adaptiveColors.surface)
                                
                                Image(systemName: "arrow.right")
                                    .font(.system(size: (customButtonFontSize ?? 12) - 1, weight: .semibold))
                                    .foregroundColor(adaptiveColors.surface)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(buttonColor)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: isImageLoaded)
            }
        }
        .frame(height: customHeight ?? 160)
        .cornerRadius(VioBorderRadius.large)
        .vioCardShadow(for: colorScheme)
        .onAppear {
            // Initialize isImageLoaded based on whether there's an image or background color
            if config.backgroundImageUrl != nil && !config.backgroundImageUrl!.isEmpty {
                // If there's an image, wait for it to load (will be updated via callback)
                isImageLoaded = false
            } else {
                // If only background color, show content immediately
                isImageLoaded = true
            }
            startCountdown()
            
            // Track component view
            // Get componentId from CampaignManager by finding the active offer_banner or countdown component
            let componentId = CampaignManager.shared.getActiveComponent(type: "offer_banner")?.id 
                ?? CampaignManager.shared.getActiveComponent(type: "countdown")?.id 
                ?? "unknown"
            AnalyticsManager.shared.trackComponentView(
                componentId: componentId,
                componentType: "offer_banner",
                componentName: config.title,
                campaignId: CampaignManager.shared.currentCampaign?.id,
                metadata: [
                    "has_countdown": config.countdownEndDate != nil,
                    "has_logo": !config.logoUrl.isEmpty,
                    "has_background_image": config.backgroundImageUrl != nil && !config.backgroundImageUrl!.isEmpty,
                    "has_background_color": config.backgroundColor != nil
                ]
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UpdateCountdown"))) { notification in
            // Only update if timer ID matches current one
            if let notificationTimerId = notification.userInfo?["timerId"] as? String,
               notificationTimerId == timerId.uuidString,
               let remaining = notification.userInfo?["remaining"] as? DateComponents {
                timeRemaining = remaining
            }
        }
        .onChange(of: config.countdownEndDate) { newDate in
            // Restart countdown when backend date changes
            timer?.invalidate()
            timer = nil
            timeRemaining = nil
            countdownEndDate = nil
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
            countdownEndDate = nil
        }
    }
    
    // MARK: - Computed Properties
    
    private var buttonColor: Color {
        if let colorString = config.buttonColor {
            return Color(hex: colorString) ?? Color.purple
        }
        return Color.purple
    }
    
    // MARK: - URL Helper
    
    private func buildFullURL(from path: String) -> String {
        // If it's already a full URL, return as is
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return path
        }
        
        // If it's a relative path, prepend the base URL from configuration
        let baseURL = VioConfiguration.shared.campaignConfiguration.restAPIBaseURL
        return baseURL + path
    }
    
    // MARK: - Logo Image View
    
    private var logoImageView: some View {
        let logoFullURL = buildFullURL(from: config.logoUrl)
        return LoadedImage(
            url: URL(string: logoFullURL),
            placeholder: AnyView(
                Rectangle()
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.3))
                    .frame(height: 16)
            ),
            errorView: AnyView(
                // Si falla la carga del logo, mostrar un placeholder visible
                Rectangle()
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.3))
                    .frame(height: 16)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 10))
                            .foregroundColor(adaptiveColors.textSecondary.opacity(0.5))
                    )
            )
        )
        .aspectRatio(contentMode: .fit)
        .frame(height: 16)
        .onAppear {
            isLogoLoaded = true
        }
    }
    
    // MARK: - Background Layer (same as hardcoded banner)
    
    private var backgroundLayer: some View {
        Group {
            if let imageUrl = config.backgroundImageUrl, !imageUrl.isEmpty {
                // Use background image
                let fullURL = buildFullURL(from: imageUrl)
                backgroundImageLayer(fullURL: fullURL)
            } else {
                // Use solid background color (no image)
                Rectangle()
                    .fill(backgroundColorFromHex(config.backgroundColor) ?? adaptiveColors.surfaceSecondary.opacity(0.2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        isImageLoaded = true
                    }
            }
        }
    }
    
    @ViewBuilder
    private func backgroundImageLayer(fullURL: String) -> some View {
        ZStack {
            // Intentar cargar la imagen con callback para detectar cuando realmente carga
            if let imageURL = URL(string: fullURL) {
                LoadedImageWithCallback(
                    url: imageURL,
                    onImageLoaded: {
                        isImageLoaded = true
                    },
                    placeholder: AnyView(
                        // Placeholder neutro mientras carga - NO mostrar backgroundColor del config
                        Rectangle()
                            .fill(adaptiveColors.surfaceSecondary.opacity(0.2))
                    ),
                    errorView: AnyView(
                        // Error view - cuando hay error, mostrar backgroundColor como fallback
                        Rectangle()
                            .fill(backgroundColorFromHex(config.backgroundColor) ?? adaptiveColors.surfaceSecondary.opacity(0.2))
                            .onAppear {
                                // Si hay error, marcar como "loaded" para mostrar el contenido con el color de fondo
                                isImageLoaded = true
                            }
                    )
                )
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Si la URL no es válida, mostrar color de fondo y marcar como loaded
                Rectangle()
                    .fill(backgroundColorFromHex(config.backgroundColor) ?? adaptiveColors.surfaceSecondary.opacity(0.2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        isImageLoaded = true
                    }
            }
            
            // Dark overlay for readability (solo cuando imagen está cargada)
            if isImageLoaded {
                LinearGradient(
                    colors: [
                        adaptiveColors.textPrimary.opacity(config.overlayOpacity ?? 0.4),
                        adaptiveColors.textPrimary.opacity((config.overlayOpacity ?? 0.4) * 0.5)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
    
    // Helper para convertir hex string a Color
    private func backgroundColorFromHex(_ hex: String?) -> Color? {
        guard let hex = hex, !hex.isEmpty else { return nil }
        
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0xFF00) >> 8) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
    
    // MARK: - Analog Countdown (same style as hardcoded banner)
    
    private func analogCountdown(timeRemaining: DateComponents) -> some View {
        let days = timeRemaining.day ?? 0
        let hours = timeRemaining.hour ?? 0
        let minutes = timeRemaining.minute ?? 0
        let seconds = timeRemaining.second ?? 0
        
        return HStack(spacing: 4) {
            // Days
            if days > 0 {
                CountdownUnit(value: days, label: days == 1 ? "dag" : "dager")
            }
            
            // Hours
            if days > 0 || hours > 0 {
                CountdownUnit(value: hours, label: hours == 1 ? "time" : "timer")
            }
            
            // Minutes
            CountdownUnit(value: minutes, label: "min")
            
            // Seconds
            CountdownUnit(value: seconds, label: "sek")
        }
        .padding(.vertical, 3)
    }
    
    private func startCountdown() {
        // Invalidate previous timer if exists
        timer?.invalidate()
        timer = nil
        
        // Generate a new ID for this timer
        let currentTimerId = UUID()
        timerId = currentTimerId
        
        // Parse the date once and store it
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        guard let endDate = formatter.date(from: config.countdownEndDate) else {
            timeRemaining = nil
            countdownEndDate = nil
            return
        }
        
        // Store the parsed date
        countdownEndDate = endDate
        
        // Calculate initial time
        let now = Date()
        if now >= endDate {
            timeRemaining = nil
            return
        }
        
        // Calculate initial remaining time
        timeRemaining = Calendar.current.dateComponents(
            [.day, .hour, .minute, .second],
            from: now,
            to: endDate
        )
        
        // Create a timer that uses the stored date
        // Capture the date and timer ID in local constants for the closure
        let finalEndDate = endDate
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            let now = Date()
            if now >= finalEndDate {
                timer.invalidate()
            } else {
                let remaining = Calendar.current.dateComponents(
                    [.day, .hour, .minute, .second],
                    from: now,
                    to: finalEndDate
                )
                // Update timeRemaining only if this timer is still the current one
                // We use NotificationCenter to communicate the change safely
                NotificationCenter.default.post(
                    name: NSNotification.Name("UpdateCountdown"),
                    object: nil,
                    userInfo: [
                        "remaining": remaining,
                        "timerId": currentTimerId.uuidString
                    ]
                )
            }
        }
        
        // Add timer to RunLoop to ensure it fires
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    /// Handle CTA button action with deeplink support
    private func handleCTAAction() {
        // Track component click
        // Get componentId from CampaignManager by finding the active offer_banner or countdown component
        let componentId = CampaignManager.shared.getActiveComponent(type: "offer_banner")?.id 
            ?? CampaignManager.shared.getActiveComponent(type: "countdown")?.id 
            ?? "unknown"
        var actionType = "cta_button"
        
        // Priority: onNavigateToStore > customDeeplink > config.deeplinkUrl > ctaLink
        if let onNavigateToStore = onNavigateToStore {
            // Navigate to store view within app
            actionType = "navigate_to_store"
            AnalyticsManager.shared.trackComponentClick(
                componentId: componentId,
                componentType: "offer_banner",
                action: actionType,
                componentName: config.title,
                campaignId: CampaignManager.shared.currentCampaign?.id,
                metadata: ["deeplink_type": "in_app"]
            )
            onNavigateToStore()
        } else if let customDeeplink = customDeeplink, !customDeeplink.isEmpty {
            actionType = "custom_deeplink"
            AnalyticsManager.shared.trackComponentClick(
                componentId: componentId,
                componentType: "offer_banner",
                action: actionType,
                componentName: config.title,
                campaignId: CampaignManager.shared.currentCampaign?.id,
                metadata: ["deeplink": customDeeplink]
            )
            handleDeeplink(url: customDeeplink, action: nil)
        } else if let deeplinkUrl = config.deeplinkUrl, !deeplinkUrl.isEmpty {
            actionType = "deeplink"
            AnalyticsManager.shared.trackComponentClick(
                componentId: componentId,
                componentType: "offer_banner",
                action: actionType,
                componentName: config.title,
                campaignId: CampaignManager.shared.currentCampaign?.id,
                metadata: ["deeplink": deeplinkUrl]
            )
            handleDeeplink(url: deeplinkUrl, action: config.deeplinkAction)
        } else if let ctaLink = config.ctaLink, !ctaLink.isEmpty {
            actionType = "external_link"
            AnalyticsManager.shared.trackComponentClick(
                componentId: componentId,
                componentType: "offer_banner",
                action: actionType,
                componentName: config.title,
                campaignId: CampaignManager.shared.currentCampaign?.id,
                metadata: ["link": ctaLink]
            )
            handleExternalLink(url: ctaLink)
        }
    }
    
    /// Handle deeplink navigation
    private func handleDeeplink(url: String, action: String?) {
        #if os(iOS)
        if let deeplinkURL = URL(string: url) {
            // Check if it's a custom scheme (deeplink)
            if deeplinkURL.scheme != "http" && deeplinkURL.scheme != "https" {
                // Custom deeplink - open with app
                if UIApplication.shared.canOpenURL(deeplinkURL) {
                    UIApplication.shared.open(deeplinkURL)
                } else {
                    // Fallback to external link if available
                    if let fallbackLink = config.ctaLink {
                        handleExternalLink(url: fallbackLink)
                    }
                }
            } else {
                // HTTP/HTTPS link - open in browser
                handleExternalLink(url: url)
            }
        }
        #endif
    }
    
    /// Handle external link (HTTP/HTTPS)
    private func handleExternalLink(url: String) {
        #if os(iOS)
        if let externalURL = URL(string: url) {
            UIApplication.shared.open(externalURL)
        }
        #endif
    }
}

/// Countdown display component
struct CountdownView: View {
    let timeRemaining: DateComponents
    
    var body: some View {
        HStack(spacing: 8) {
            TimeUnit(value: timeRemaining.day ?? 0, label: "dager")
            TimeUnit(value: timeRemaining.hour ?? 0, label: "timer")
            TimeUnit(value: timeRemaining.minute ?? 0, label: "min")
            TimeUnit(value: timeRemaining.second ?? 0, label: "sek")
        }
    }
}

/// Individual time unit display
struct TimeUnit: View {
    let value: Int
    let label: String
    
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: SwiftUI.ColorScheme
    
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(adaptiveColors.surface)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(adaptiveColors.surface.opacity(0.7))
        }
        .frame(width: 40, height: 50)
        .background(
            RoundedRectangle(cornerRadius: VioBorderRadius.small)
                .stroke(adaptiveColors.surface.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Dynamic Banner Container
/// Dynamic Offer Banner component that automatically loads configuration from backend
/// This component connects to ComponentManager and displays the active banner
/// It handles loading states, errors, and real-time updates via WebSocket
public struct VOfferBannerDynamic: View {
    @ObservedObject private var componentManager = ComponentManager.shared
    @ObservedObject private var campaignManager = CampaignManager.shared
    @State private var isLoading = true
    @State private var hasError = false
    @State private var errorMessage: String?
    @State private var hasShownInitialSkeleton = false
    
    // Optional callback for navigation to store
    let onNavigateToStore: (() -> Void)?
    
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: SwiftUI.ColorScheme
    
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    public init(onNavigateToStore: (() -> Void)? = nil) {
        self.onNavigateToStore = onNavigateToStore
    }
    
    /// Should show component
    /// Follows the same pattern as VProductStore, VProductCarousel, etc.
    private var shouldShow: Bool {
        // Check SDK availability
        guard VioConfiguration.shared.shouldUseSDK else {
            return false
        }
        
        // Check campaign state
        let campaignId = CampaignManager.shared.currentCampaign?.id ?? 0
        guard campaignId > 0 else {
            // No campaign configured - show component (legacy behavior)
            return true
        }
        
        // Campaign must be active and not paused
        guard campaignManager.isCampaignActive,
              campaignManager.currentCampaign?.isPaused != true else {
            return false
        }
        
        // Show component if banner exists OR if we're loading (to show skeleton)
        return componentManager.activeBanner != nil || isLoading
    }
    
    public var body: some View {
        Group {
            if !shouldShow && !isLoading {
                EmptyView()
            } else {
                ZStack {
                    // Determine if we should show skeleton
                    // Show skeleton only when: loading AND no banner available, OR initial load hasn't completed
                    let showSkeleton = (isLoading && componentManager.activeBanner == nil) || (!hasShownInitialSkeleton && componentManager.activeBanner == nil)
                    
                    loadingSkeleton
                        .opacity(showSkeleton ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.3), value: showSkeleton)
                    
                    // Error view
                    if hasError && !isLoading && componentManager.activeBanner == nil {
                        errorView
                            .opacity(1.0)
                            .animation(.easeInOut(duration: 0.3), value: hasError)
                    }
                    
                    // Content - show when banner is available and skeleton should be hidden
                    if let bannerConfig = componentManager.activeBanner {
                        VOfferBanner(
                            config: bannerConfig,
                            onNavigateToStore: onNavigateToStore
                        )
                            .id("\(bannerConfig.countdownEndDate)-\(bannerConfig.title)") // Force recreation when config changes
                            .opacity(showSkeleton ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: showSkeleton)
                    }
                }
            }
            // If no banner and not loading, show nothing (banner is hidden)
        }
        .onAppear {
            // Check if banner is already available
            if componentManager.activeBanner != nil && componentManager.isConnected {
                // Banner already available - show it immediately
                hasShownInitialSkeleton = true
                isLoading = false
            } else if componentManager.activeBanner != nil {
                // Banner available but connection status unknown - show it anyway
                hasShownInitialSkeleton = true
                isLoading = false
            } else {
                // No banner yet - show skeleton and connect
                hasShownInitialSkeleton = false
                
                Task {
                    // Small delay to ensure skeleton is visible
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    hasShownInitialSkeleton = true
                    
                    await connectToBackend()
                }
            }
        }
        .onDisappear {
            // Note: We don't disconnect here to allow WebSocket to keep receiving updates
            // ComponentManager manages its own lifecycle
        }
        .onChange(of: componentManager.activeBanner) { newBanner in
            // Update state when banner changes
            if newBanner != nil {
                // Banner became available
                isLoading = false
                hasError = false
                hasShownInitialSkeleton = true // Ensure skeleton is hidden
            } else {
                // Banner was removed - only set loading if we're actually loading
                // Don't set isLoading to true here, as the banner might just be temporarily unavailable
                if isLoading {
                    // Keep loading state if we're already loading
                } else {
                    // Banner removed but not loading - this is normal (no active banner)
                    isLoading = false
                }
            }
        }
        .onChange(of: componentManager.isConnected) { isConnected in
            // When connection status changes, check if we should update loading state
            if isConnected && componentManager.activeBanner != nil {
                // Connected and banner available - ensure we're not loading
                isLoading = false
                hasShownInitialSkeleton = true
            }
        }
    }
    
    // MARK: - Loading Skeleton
    
    private var loadingSkeleton: some View {
        ZStack {
            // Background skeleton
            Rectangle()
                .fill(adaptiveColors.surfaceSecondary.opacity(0.2))
                .cornerRadius(VioBorderRadius.large)
            
            // Content skeleton
            HStack(alignment: .center, spacing: 16) {
                // Left column skeleton
                VStack(alignment: .leading, spacing: 4) {
                    // Logo skeleton
                    Rectangle()
                        .fill(adaptiveColors.surfaceSecondary.opacity(0.3))
                        .frame(width: 100, height: 16)
                        .cornerRadius(VioBorderRadius.small)
                    
                    // Title skeleton
                    Rectangle()
                        .fill(adaptiveColors.surfaceSecondary.opacity(0.3))
                        .frame(height: 24)
                        .frame(maxWidth: 150)
                        .cornerRadius(VioBorderRadius.small)
                    
                    // Subtitle skeleton
                    Rectangle()
                        .fill(adaptiveColors.surfaceSecondary.opacity(0.2))
                        .frame(height: 11)
                        .frame(maxWidth: 120)
                        .cornerRadius(VioBorderRadius.small / 2)
                    
                    // Countdown skeleton
                    HStack(spacing: 4) {
                        ForEach(0..<4) { _ in
                            Rectangle()
                                .fill(adaptiveColors.surfaceSecondary.opacity(0.3))
                                .frame(width: 30, height: 20)
                                .cornerRadius(VioBorderRadius.small)
                        }
                    }
                    .padding(.vertical, 3)
                }
                
                Spacer()
                
                // Right column skeleton
                VStack(spacing: 8) {
                    // Badge skeleton
                    Rectangle()
                        .fill(adaptiveColors.surfaceSecondary.opacity(0.4))
                        .frame(width: 80, height: 32)
                        .cornerRadius(VioBorderRadius.circle)
                    
                    // Button skeleton
                    Rectangle()
                        .fill(adaptiveColors.surfaceSecondary.opacity(0.4))
                        .frame(width: 100, height: 28)
                        .cornerRadius(VioBorderRadius.circle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(height: 160)
        .cornerRadius(VioBorderRadius.large)
        .shimmerEffect()
    }
    
    // MARK: - Error View
    
    private var errorView: some View {
        Group {
            // Optionally show error - for now, just hide the banner
            // Uncomment below if you want to show error state
            /*
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24))
                    .foregroundColor(adaptiveColors.error)
                
                Text("Failed to load banner")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(adaptiveColors.textPrimary)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(adaptiveColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .background(adaptiveColors.surfaceSecondary.opacity(0.1))
            .cornerRadius(VioBorderRadius.large)
            */
        }
    }
    
    // MARK: - Connection Logic
    
    private func connectToBackend() async {
        // If banner is already available and connected, don't reconnect
        if componentManager.activeBanner != nil && componentManager.isConnected {
            isLoading = false
            return
        }
        
        isLoading = true
        hasError = false
        errorMessage = nil
        
        do {
            await componentManager.connect()
            
            // Wait a bit for initial load, but check periodically if banner becomes available
            var waited = 0
            let maxWait = 10_000_000_000 // 1 second total
            let checkInterval = 100_000_000 // Check every 100ms
            
            while waited < maxWait {
                try await Task.sleep(nanoseconds: UInt64(checkInterval))
                waited += checkInterval
                
                // If banner becomes available, stop waiting
                if componentManager.activeBanner != nil {
                    isLoading = false
                    return
                }
            }
            
            // Check if we got a banner or if connection is established
            if componentManager.activeBanner == nil && componentManager.isConnected {
                // Connected but no active banner - this is normal, not an error
                isLoading = false
            } else if componentManager.activeBanner != nil {
                // Got a banner!
                isLoading = false
            } else {
                // Still loading or connection failed
                isLoading = false
                // Don't set error - might just be no active banner
            }
        } catch {
            hasError = true
            errorMessage = error.localizedDescription
            isLoading = false
            VioLogger.error("Failed to connect to banner backend: \(error)", component: "VOfferBannerDynamic")
        }
    }
}

// MARK: - Shimmer Effect Extension (private to avoid conflicts)

private extension View {
    func shimmerEffect() -> some View {
        self.modifier(ShimmerModifier())
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 200 - 100)
                .animation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false),
                    value: phase
                )
            )
            .onAppear {
                phase = 1
            }
    }
}

/// Container view that manages the offer banner lifecycle (legacy name - use VOfferBannerDynamic)
@available(*, deprecated, renamed: "VOfferBannerDynamic", message: "Use VOfferBannerDynamic instead")
public struct VOfferBannerContainer: View {
    public init() {}
    
    public var body: some View {
        VOfferBannerDynamic()
    }
}

/// Countdown Unit Component (same style as hardcoded banner)
struct CountdownUnit: View {
    let value: Int
    let label: String
    
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: SwiftUI.ColorScheme
    
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    var body: some View {
        VStack(spacing: 1) {
            // Digits
            Text(String(format: "%02d", value))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(adaptiveColors.surface)
                .frame(minWidth: 24)
                .padding(.vertical, 2)
                .padding(.horizontal, 5)
                .background(
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(adaptiveColors.surface.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: VioBorderRadius.small)
                                .stroke(adaptiveColors.surface.opacity(0.3), lineWidth: 1)
                        )
                )
            
            // Label
            Text(label)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(adaptiveColors.surface.opacity(0.85))
        }
    }
}

// MARK: - LoadedImageWithCallback

/// LoadedImage wrapper that calls a callback when image is loaded
private struct LoadedImageWithCallback: View {
    let url: URL
    let onImageLoaded: () -> Void
    let placeholder: AnyView
    let errorView: AnyView
    
    @StateObject private var loader = ImageLoader()
    @State private var hasCalledCallback = false
    
    var body: some View {
        Group {
            if let image = loader.image {
                image
                    .resizable()
                    .onAppear {
                        if !hasCalledCallback {
                            hasCalledCallback = true
                            onImageLoaded()
                        }
                    }
            } else if loader.isLoading {
                placeholder
            } else if loader.error != nil {
                errorView
                    .onAppear {
                        // Even on error, mark as "loaded" so content can show with fallback color
                        if !hasCalledCallback {
                            hasCalledCallback = true
                            onImageLoaded()
                        }
                    }
            } else {
                placeholder
            }
        }
        .onAppear {
            loader.load(url: url)
        }
        .onChange(of: url) { newURL in
            hasCalledCallback = false
            loader.load(url: newURL)
        }
        .onChange(of: loader.image) { image in
            if image != nil && !hasCalledCallback {
                hasCalledCallback = true
                onImageLoaded()
            }
        }
        .onDisappear {
            loader.cancel()
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#if DEBUG
/// Preview for development
struct VOfferBanner_Previews: PreviewProvider {
    static var previews: some View {
        VOfferBanner(config: OfferBannerConfig(
            logoUrl: "https://example.com/logo.png",
            title: "Ukens tilbud",
            subtitle: "Se denne ukes beste tilbud",
            backgroundImageUrl: "https://example.com/background.jpg",
            backgroundColor: nil,
            countdownEndDate: "2025-12-31T23:59:59Z",
            discountBadgeText: "Opp til 30%",
            ctaText: "Se alle tilbud →",
            ctaLink: "https://example.com/offers",
            overlayOpacity: 0.4,
            buttonColor: "#FF6B35"
        ))
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
