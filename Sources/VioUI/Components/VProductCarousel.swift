import SwiftUI
import VioCore
import VioDesignSystem

#if os(iOS)
import UIKit
#endif

/// Auto-configured Product Carousel component
/// Automatically loads configuration from active campaign
/// 
/// **Usage:**
/// ```swift
/// // Basic usage - uses layout from backend config
/// VProductCarousel()
///
/// // Override layout for testing/comparison
/// VProductCarousel(layout: "full")      // Large vertical cards (full width)
/// VProductCarousel(layout: "compact")   // Small vertical cards (2 cards visible)
/// VProductCarousel(layout: "horizontal") // Horizontal cards (image left, info right)
/// ```
///
/// **Parameters:**
/// - `layout: String?` - Optional layout override. Options: `"full"`, `"compact"`, `"horizontal"`. If `nil`, uses layout from backend config.
///
/// **Backend Configuration (from API):**
/// The component reads configuration from `GET /api/campaigns/{campaignId}/components`:
/// ```json
/// {
///   "components": [{
///     "componentId": "product_carousel_1",
///     "status": "active",
///     "customConfig": {
///       "productIds": ["408841", "408842", "408843"],
///       "autoPlay": true,
///       "interval": 4000,
///       "layout": "full"
///     }
///   }]
/// }
/// ```
///
/// **Configuration Properties:**
/// - `productIds: [String]` - Array of product IDs. **Empty array or missing field loads ALL products from channel.**
/// - `autoPlay: Bool` - Enable/disable auto-scroll (default: `false` if not provided)
/// - `interval: Int` - Auto-scroll interval in milliseconds (default: `3000` if not provided)
/// - `layout: String?` - Layout type: `"full"`, `"compact"`, or `"horizontal"` (default: `"full"`)
///
/// **Layout Details:**
/// - `"full"`: Cards use full width minus padding, height is 2.0x width
/// - `"compact"`: Shows 2 cards at once, each card is ~47% of screen width
/// - `"horizontal"`: Cards are 90% width, 140px height, image left/description right
///
/// **Features:**
/// - ✅ Skeleton loader while loading
/// - ✅ Auto-scroll support (configurable interval)
/// - ✅ Automatic fallback to all products if no IDs provided
/// - ✅ Responsive card sizing
/// - ✅ Uses design system tokens (colors, spacing, shadows, border radius)
public struct VProductCarousel: View {
    
    // MARK: - Cached Config Values
    
    /// Internal structure to cache parsed config values
    /// This avoids recalculating conversions and values on every render
    private struct CachedConfig {
        let productIds: [Int]  // Empty array means "load all products from channel"
        let autoPlayInterval: TimeInterval
        let shouldAutoPlay: Bool
        let layout: String // "compact", "full", or "horizontal"
        let title: String?           // Optional header title from operator's customConfig
        let showSponsorLogo: Bool    // Optional flag to render the placement's sponsor logo in the header
        let configId: String // Used to detect config changes

        init(config: ProductCarouselConfig, layoutOverride: String? = nil) {
            // Cache converted product IDs (String → Int)
            // Empty array means "load all products from channel"
            self.productIds = config.productIds.compactMap { Int($0) }

            // Cache auto-play interval conversion (milliseconds → seconds)
            self.autoPlayInterval = Double(config.interval) / 1000.0
            self.shouldAutoPlay = config.autoPlay

            // Use layout override if provided, otherwise use layout from config (default to "full")
            self.layout = layoutOverride ?? config.layout ?? "full"

            // Optional header opt-ins (default to off; operator turns them
            // on per placement via the dashboard's customConfig fields).
            self.title = config.title
            self.showSponsorLogo = config.showSponsorLogo

            // Create unique identifier for this config (detects changes)
            // Use "all" when productIds is empty to make it clearer
            // Must match the format in updateCachedConfigIfNeeded()
            let productIdsString = config.productIds.isEmpty ? "all" : config.productIds.joined(separator: "-")
            self.configId = "\(productIdsString)-\(config.autoPlay)-\(config.interval)-\(self.layout)-\(config.title ?? "")-\(config.showSponsorLogo)"
        }
    }
    
    // MARK: - Properties
    
    @ObservedObject private var campaignManager = CampaignManager.shared
    @StateObject private var viewModel = VProductCarouselViewModel()
    @State private var autoScrollTimer: Timer?
    @State private var showingProductDetail: Product? // For product detail overlay
    @State private var scrollOffset: CGFloat = 0 // For tracking scroll position
    
    // Cache parsed config values - only recalculated when config changes
    @State private var cachedConfig: CachedConfig?
    @State private var currentConfigId: String?
    
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: SwiftUI.ColorScheme
    
    // MARK: - Properties
    
    /// Optional component ID to identify a specific component
    /// If nil, uses the first matching component from the campaign
    private let componentId: String?
    private let locationId: String?
    
    // MARK: - Properties for Demo/Testing
    
    /// Optional layout override for demo/testing purposes
    /// If set, overrides the layout from backend config
    /// Options: "full", "compact", "horizontal"
    private let layout: String?
    
    /// Whether to show the "Add to Cart" button in full layout cards
    /// Default: false (button hidden)
    private let showAddToCartButton: Bool
    
    /// Whether to show sponsor badge above/below carousel
    /// Badge displays campaign logo with "Sponset av" text
    /// Logo is fetched from campaign configuration (campaignLogo field)
    /// Default: false (badge hidden)
    /// If true, badge will be shown if campaignLogo is available from campaign
    private let showSponsor: Bool
    
    /// Sponsor badge position: "topRight", "topLeft", "bottomRight", "bottomLeft"
    /// Badge is displayed in a separate container (like a div) above or below the carousel
    /// Default: "topRight"
    private let sponsorPosition: String
    
    /// Background color for product images
    /// Useful for PNG images without background to avoid transparency issues
    /// Default: .white
    private let imageBackgroundColor: Color
    
    // MARK: - Initializer
    
    public init(componentId: String? = nil, locationId: String? = nil, layout: String? = nil, showAddToCartButton: Bool = false, showSponsor: Bool = false, sponsorPosition: String? = nil, imageBackgroundColor: Color? = nil) {
        // Optional component ID to identify a specific component
        self.componentId = componentId
        self.locationId = locationId
        // Optional layout override for demo/testing (e.g., "full", "compact", "horizontal")
        // If nil, uses layout from backend config
        self.layout = layout
        self.showAddToCartButton = showAddToCartButton
        self.showSponsor = showSponsor
        // Default to "topRight" if not specified
        self.sponsorPosition = sponsorPosition ?? "topRight"
        // Default to white if not specified
        self.imageBackgroundColor = imageBackgroundColor ?? .white
    }
    
    // MARK: - Computed Properties
    
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    /// Get active product carousel component from campaign
    private var activeComponent: Component? {
        campaignManager.getActiveComponent(type: "product_carousel", componentId: componentId, locationId: locationId)
    }
    
    /// Extract ProductCarouselConfig from component
    private var config: ProductCarouselConfig? {
        guard let component = activeComponent,
              case .productCarousel(let config) = component.config else {
            return nil
        }
        return config
    }
    
    /// Get a unique identifier based on productIds to detect config changes
    /// This helps detect when productIds change from backend even if component ID stays the same
    private var configProductIdsId: String {
        config?.productIds.joined(separator: "-") ?? ""
    }
    
    /// Update cached config when config changes
    private func updateCachedConfigIfNeeded() {
        guard let config = config else {
            if cachedConfig != nil {
                cachedConfig = nil
                currentConfigId = nil
            }
            return
        }
        
        // Use layout override if provided, otherwise use layout from config
        let effectiveLayout = layout ?? config.layout ?? "full"
        
        // Use "all" when productIds is empty to match CachedConfig.init
        let productIdsString = config.productIds.isEmpty ? "all" : config.productIds.joined(separator: "-")
        let newConfigId = "\(productIdsString)-\(config.autoPlay)-\(config.interval)-\(effectiveLayout)"
        
        // Only recalculate if config actually changed
        if currentConfigId != newConfigId {
            cachedConfig = CachedConfig(config: config, layoutOverride: layout)
            currentConfigId = newConfigId
        }
    }
    
    /// Should show component
    private var shouldShow: Bool {
        // Check SDK availability
        guard VioConfiguration.shared.shouldUseSDK else {
            return false
        }

        // Hide-on-failure: when the product fetch failed and we have no
        // cached products to render, fall through to EmptyView instead
        // of showing a perpetual skeleton or an error CTA. Operator
        // fixes the binding via dashboard → next config change resets
        // the flag and the next loadProducts attempts again.
        // Sprint 2026-04-28 PM Phase 2 polish.
        if viewModel.loadFailed && viewModel.products.isEmpty {
            return false
        }

        // Check campaign state
        let campaignId = CampaignManager.shared.currentCampaign?.id ?? 0
        guard campaignId > 0 else {
            return config != nil
        }

        // Campaign must be active and not paused
        guard campaignManager.isCampaignActive,
              campaignManager.currentCampaign?.isPaused != true else {
            return false
        }

        // Component must exist and be active
        // Also check if config can be extracted (component might exist but config decoding failed)
        return activeComponent?.isActive == true && config != nil
    }
    
    /// Products to display
    private var products: [Product] {
        viewModel.products
    }
    
    /// Should show loading state
    private var shouldShowLoading: Bool {
        viewModel.isLoading && viewModel.products.isEmpty
    }
    
    /// Should show error state
    private var shouldShowError: Bool {
        viewModel.errorMessage != nil && viewModel.products.isEmpty && !viewModel.isMarketUnavailable
    }
    
    /// Should hide component (market unavailable)
    private var shouldHide: Bool {
        viewModel.isMarketUnavailable
    }
    
    /// Get campaign logo URL from current campaign
    private var campaignLogoUrl: String? {
        campaignManager.currentCampaign?.campaignLogo
    }
    
    
    /// Should show sponsor badge
    private var shouldShowSponsorBadge: Bool {
        guard showSponsor else { return false }
        guard let logo = campaignLogoUrl, !logo.isEmpty else { return false }
        return true
    }
    
    // MARK: - Body
    
    /// Get effective config, calculating if needed
    private var effectiveConfig: ProductCarouselConfig? {
        guard let config = config else { return nil }
        return config
    }
    
    /// Content view without modifiers
    private var contentView: some View {
        Group {
            if !shouldShow {
                EmptyView()
            } else if shouldHide {
                EmptyView()
            } else if effectiveConfig != nil {
                mainContentView
            } else {
                // Show skeleton loader while waiting for config
                skeletonView
            }
        }
    }
    
    /// Main content view with skeleton, carousel, and sponsor badge
    private var mainContentView: some View {
        let currentLogoUrl = campaignLogoUrl
        let shouldShowBadge = shouldShowSponsorBadge
        let isLoading = shouldShowLoading || products.isEmpty
        let position = sponsorPosition.isEmpty ? "topRight" : sponsorPosition
        
        // Determine if badge should be above or below carousel
        let isTopPosition = position == "topRight" || position == "topLeft"
        let isRightPosition = position == "topRight" || position == "bottomRight"
        
        return ZStack {
            // Skeleton - fades out when content is ready
            skeletonView
                .opacity(isLoading ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3), value: isLoading)

            // Content with badge container
            VStack(spacing: 0) {
                // Optional config-driven header (title + sponsor logo).
                // Both are opt-in via the placement's customConfig in the
                // dashboard — if the operator doesn't set them, no header
                // renders and the carousel sits without a label (current
                // legacy behavior preserved).
                placementHeader
                    .opacity(isLoading ? 0.0 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isLoading)

                // Badge container above carousel (if top position)
                if shouldShowBadge, let logoUrl = currentLogoUrl, isTopPosition {
                    sponsorBadgeContainer(logoUrl: logoUrl, isRightPosition: isRightPosition)
                        .opacity(isLoading ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isLoading)
                }

                // Carousel content
                carouselContent
                    .opacity(isLoading ? 0.0 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isLoading)

                // Badge container below carousel (if bottom position)
                if shouldShowBadge, let logoUrl = currentLogoUrl, !isTopPosition {
                    sponsorBadgeContainer(logoUrl: logoUrl, isRightPosition: isRightPosition)
                        .opacity(isLoading ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: isLoading)
                }
            }
        }
    }

    /// Header strip with optional title text + sponsor logo. Both come from
    /// the placement's config — operator-controllable via the dashboard's
    /// customConfig fields:
    ///
    ///   `title`             → "Ukens tilbud", "Featured", etc. Empty/nil → hide.
    ///   `showSponsorLogo`   → bool. true → resolve sponsor.logoUrl by sponsorId
    ///                                        and render right-aligned.
    ///
    /// Renders nothing when both opts are off (zero overhead, no extra
    /// padding, no spacer block). Replaces the host app's hand-rolled
    /// "Ukens tilbud" Text + Image("logo") wrapper around the carousel.
    @ViewBuilder
    private var placementHeader: some View {
        let title = (cachedConfig?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let showLogo = cachedConfig?.showSponsorLogo == true
        // Render the operator-uploaded **logoUrl** (the official brand logo
        // — what the dashboard's "Logo" field accepts). Format-agnostic:
        // VRemoteImage routes raster (PNG/JPEG) through AsyncImage and
        // vector (.svg) through a WKWebView fallback so SVG logos render
        // without adding a third-party dep. AvatarUrl is reserved for
        // surfaces that explicitly want the square mark (cards, badges).
        let sponsorLogoUrl: String? = {
            guard showLogo, let sponsorId = activeComponent?.sponsorId else { return nil }
            return VioConfiguration.shared.sponsor(withId: sponsorId)?.logoUrl
        }()
        if !title.isEmpty || sponsorLogoUrl != nil {
            HStack {
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(adaptiveColors.textPrimary)
                }
                Spacer()
                if let url = sponsorLogoUrl {
                    VRemoteImage(urlString: url, height: 20)
                }
            }
            .padding(.horizontal, VioSpacing.md)
            .padding(.bottom, VioSpacing.sm)
        }
    }
    
    /// Sponsor badge container (like a div) positioned above or below carousel
    /// Badge is displayed in its own container to avoid overlapping with product cards
    /// Positioned horizontally (left/right) within the container based on sponsorPosition parameter
    /// - Parameters:
    ///   - logoUrl: URL of the campaign sponsor logo
    ///   - isRightPosition: Whether badge should be aligned to the right (true) or left (false)
    private func sponsorBadgeContainer(logoUrl: String, isRightPosition: Bool) -> some View {
        HStack {
            if isRightPosition {
                Spacer()
            }
            
            VSponsorBadge(logoUrl: logoUrl)
                .padding(.horizontal, VioSpacing.xs)
                .padding(.vertical, VioSpacing.xs)
            
            if !isRightPosition {
                Spacer()
            }
        }
        .padding(.horizontal, VioSpacing.sm)
        .padding(.vertical, VioSpacing.xs)
    }
    
    public var body: some View {
        contentView
            .onChange(of: campaignManager.isCampaignActive) { _ in
                handleCampaignStateChange()
            }
            .onChange(of: campaignManager.currentCampaign?.isPaused) { _ in
                handleCampaignStateChange()
            }
            .onChange(of: campaignManager.currentCampaign) { campaign in
                handleCampaignChange(campaign)
            }
            .onChange(of: campaignManager.activeComponents.count) { _ in
                handleComponentChange()
            }
            .onChange(of: activeComponent?.id) { _ in
                handleComponentChange()
            }
            .onChange(of: configProductIdsId) { _ in
                handleComponentChange()
            }
            .onAppear {
                handleOnAppear()
            }
            .task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                handleComponentChange()
            }
            .onDisappear {
                stopAutoScroll()
            }
            .sheet(item: $showingProductDetail) { product in
                // Resolve sponsorId for routing: prefer the placement's
                // own sponsorId (multi-sponsor case), fall back to the
                // primary sponsor of the active campaign. The fallback
                // catches cases where a component instance was decoded
                // before sponsorId was populated, or live-updated by a
                // legacy WS event that drops the field.
                VProductDetailOverlay(
                    product: product,
                    sponsorId: activeComponent?.sponsorId
                        ?? VioConfiguration.shared.primarySponsor?.id,
                    onDismiss: {
                        showingProductDetail = nil
                    }
                )
            }
    }
    
    /// Handle onAppear logic separately to avoid type-checking issues
    private func handleOnAppear() {
        handleComponentChange()
        
        // Track component view
        if let component = activeComponent, let config = cachedConfig {
            AnalyticsManager.shared.trackComponentView(
                componentId: component.id,
                componentType: "product_carousel",
                componentName: component.name,
                campaignId: campaignManager.currentCampaign?.id,
                metadata: [
                    "layout": config.layout,
                    "product_count": products.count,
                    "has_product_ids": !config.productIds.isEmpty,
                    "auto_play": config.shouldAutoPlay
                ]
            )
        }
    }
    
    // MARK: - Content Views
    
    private var carouselContent: some View {
        // Use layout override if provided, otherwise use layout from config
        let currentLayout = layout ?? cachedConfig?.layout ?? "full"
        
        switch currentLayout {
        case "compact":
            return AnyView(carouselContentCompact)
        case "horizontal":
            return AnyView(carouselContentHorizontal)
        default: // "full"
            return AnyView(carouselContentFull)
        }
    }
    
    /// Full layout carousel (default)
    private var carouselContentFull: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let horizontalPadding = VioSpacing.md * 2 // Padding on both sides
            // Use full width minus padding
            let cardWidth = screenWidth - horizontalPadding
            let cardHeight = cardWidth * 1.3 // Balanced aspect ratio (approximately 3:4)
            
            VStack(spacing: 4) { // Reduced spacing between card and indicators for full layout
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VioSpacing.md) {
                            ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                                productCardView(product: product)
                                    .frame(width: cardWidth, height: cardHeight)
                                    .id(index)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: ScrollOffsetPreferenceKey.self,
                                                value: geo.frame(in: .named("scroll")).minX
                                            )
                                        }
                                    )
                            }
                        }
                        .padding(.horizontal, VioSpacing.md)
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        // Calculate current index based on scroll position
                        let cardWidthWithSpacing = cardWidth + VioSpacing.md
                        let index = Int(round(-value / cardWidthWithSpacing))
                        if index >= 0 && index < viewModel.products.count {
                            viewModel.currentIndex = index
                        }
                    }
                    .onAppear {
                        startAutoScroll(proxy: proxy)
                    }
                    .onChange(of: viewModel.products.count) { _ in
                        // Restart auto-scroll when products change
                        startAutoScroll(proxy: proxy)
                        viewModel.currentIndex = 0
                    }
                    .onChange(of: cachedConfig?.configId) { _ in
                        // Restart auto-scroll when config changes (e.g., interval or autoPlay)
                        startAutoScroll(proxy: proxy)
                    }
                }
                .frame(width: screenWidth, height: cardHeight)
                
                // Page indicators (closer spacing for full layout)
                if viewModel.products.count > 1 {
                    pageIndicatorsFull
                }
            }
        }
        .aspectRatio(1.0 / 1.3, contentMode: .fit) // Maintain balanced aspect ratio
    }
    
    /// Compact layout carousel
    private var carouselContentCompact: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let horizontalPadding = VioSpacing.md * 2 // Padding on both sides
            let spacing = VioSpacing.md // Spacing between cards
            // Calculate card width to show 2 cards at once
            let cardWidth = (screenWidth - horizontalPadding - spacing) / 2.0
            
            VStack(spacing: VioSpacing.sm) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VioSpacing.md) {
                            ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                                productCardView(product: product)
                                    .frame(width: cardWidth) // Let card height adjust naturally
                                    .id(index)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: ScrollOffsetPreferenceKey.self,
                                                value: geo.frame(in: .named("scroll")).minX
                                            )
                                        }
                                    )
                            }
                        }
                        .padding(.horizontal, VioSpacing.md)
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        // Calculate current index based on scroll position
                        let cardWidthWithSpacing = cardWidth + VioSpacing.md
                        let index = Int(round(-value / cardWidthWithSpacing))
                        if index >= 0 && index < viewModel.products.count {
                            viewModel.currentIndex = index
                        }
                    }
                    .onAppear {
                        startAutoScroll(proxy: proxy)
                    }
                    .onChange(of: viewModel.products.count) { _ in
                        // Restart auto-scroll when products change
                        startAutoScroll(proxy: proxy)
                        viewModel.currentIndex = 0
                    }
                    .onChange(of: cachedConfig?.configId) { _ in
                        // Restart auto-scroll when config changes (e.g., interval or autoPlay)
                        startAutoScroll(proxy: proxy)
                    }
                }
                
                // Page indicators
                if viewModel.products.count > 1 {
                    pageIndicators
                }
            }
        }
        .frame(height: 300) // Fixed height to prevent overlap with other components
    }
    
    /// Horizontal layout carousel (image left, description right)
    private var carouselContentHorizontal: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let cardWidth = screenWidth * 0.9 // 90% of screen width for horizontal cards
            let cardHeight: CGFloat = 110 // Reduced height for horizontal cards
            
            VStack(spacing: VioSpacing.sm) {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: VioSpacing.md) {
                            ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                                horizontalProductCardView(product: product)
                                    .frame(width: cardWidth, height: cardHeight)
                                    .id(index)
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: ScrollOffsetPreferenceKey.self,
                                                value: geo.frame(in: .named("scroll")).minX
                                            )
                                        }
                                    )
                            }
                        }
                        .padding(.horizontal, VioSpacing.md)
                    }
                    .coordinateSpace(name: "scroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        // Calculate current index based on scroll position
                        let cardWidthWithSpacing = cardWidth + VioSpacing.md
                        let index = Int(round(-value / cardWidthWithSpacing))
                        if index >= 0 && index < viewModel.products.count {
                            viewModel.currentIndex = index
                        }
                    }
                    .onAppear {
                        startAutoScroll(proxy: proxy)
                    }
                    .onChange(of: viewModel.products.count) { _ in
                        // Restart auto-scroll when products change
                        startAutoScroll(proxy: proxy)
                        viewModel.currentIndex = 0
                    }
                    .onChange(of: cachedConfig?.configId) { _ in
                        // Restart auto-scroll when config changes (e.g., interval or autoPlay)
                        startAutoScroll(proxy: proxy)
                    }
                }
                
                // Page indicators
                if viewModel.products.count > 1 {
                    pageIndicators
                }
            }
        }
        .frame(height: 110) // Reduced height for horizontal cards
    }
    
    private func productCardView(product: Product) -> some View {
        let currentLayout = layout ?? cachedConfig?.layout ?? "full"
        
        // Use custom layout for "full" to avoid oversized hero variant
        if currentLayout == "full" {
            return AnyView(fullLayoutProductCardView(product: product))
        } else {
            // For compact and horizontal layouts, use grid variant without extra padding
            return AnyView(VProductCard(product: product, variant: .grid, imageBackgroundColor: imageBackgroundColor))
        }
    }
    
    
    /// Custom full layout product card with balanced sizing
    @ViewBuilder
    private func fullLayoutProductCardView(product: Product) -> some View {
        let adaptiveColors = VioColors.adaptive(for: colorScheme)
        
        // Sort images by order field (prioritizing 0 and 1)
        let sortedImages = product.images.sorted { first, second in
            let firstPriority = (first.order == 0 || first.order == 1) ? first.order : Int.max
            let secondPriority = (second.order == 0 || second.order == 1) ? second.order : Int.max
            
            if firstPriority != secondPriority {
                return firstPriority < secondPriority
            }
            return first.order < second.order
        }
        
        let primaryImageUrl = sortedImages.first?.url
        
        Button(action: {
            // Track product click
            if let component = activeComponent {
                AnalyticsManager.shared.trackProductViewed(
                    productId: String(product.id),
                    productName: product.title,
                    productPrice: Double(product.price.amount),
                    productCurrency: product.price.currency_code,
                    source: "product_carousel",
                    componentId: component.id,
                    componentType: "product_carousel"
                )
            }
            
            // Handle tap - show product detail
            showingProductDetail = product
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // Product Image
                if let imageUrl = primaryImageUrl, let url = URL(string: imageUrl) {
                    ZStack {
                        // Background color for PNG images without background
                        Rectangle()
                            .fill(imageBackgroundColor)
                        
                        LoadedImage(
                            url: url,
                            placeholder: AnyView(Rectangle()
                                .fill(adaptiveColors.surfaceSecondary)
                                .overlay { VCustomLoader(style: .rotate, size: 30) }),
                            errorView: AnyView(Rectangle()
                                .fill(adaptiveColors.surfaceSecondary)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundColor(adaptiveColors.textSecondary)
                                })
                        )
                        .aspectRatio(contentMode: .fit)
                    }
                    .frame(maxWidth: .infinity) // Use full width, let height adjust naturally
                } else {
                    Rectangle()
                        .fill(imageBackgroundColor)
                        .frame(height: 200)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(adaptiveColors.textSecondary)
                        }
                }
                
                // Product Info
                VStack(alignment: .leading, spacing: VioSpacing.xs) {
                    if let brand = product.brand {
                        Text(brand)
                            .font(.system(size: 10, weight: .medium)) // Smaller brand text
                            .foregroundColor(adaptiveColors.textSecondary)
                            .textCase(.uppercase)
                    }
                    
                    Text(product.title)
                        .font(.system(size: 14, weight: .semibold)) // Smaller title
                        .foregroundColor(adaptiveColors.textPrimary)
                        .lineLimit(2)
                    
                    HStack {
                        // Price
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.price.displayAmount)
                                .font(.system(size: 16, weight: .bold)) // Adjusted price size
                                .foregroundColor(adaptiveColors.priceColor)
                            
                            if let compareAtAmount = product.price.displayCompareAtAmount {
                                Text(compareAtAmount)
                                    .font(.system(size: 12, weight: .regular)) // Smaller compare price
                                    .foregroundColor(adaptiveColors.textSecondary)
                                    .strikethrough()
                            } else {
                                // Spacer to maintain consistent height
                                Text("")
                                    .font(.system(size: 12, weight: .regular))
                                    .opacity(0)
                            }
                        }
                        .frame(minHeight: 32)  // Fixed minimum height for consistent card sizes
                        
                        if showAddToCartButton {
                            Spacer()
                            
                            // Add to Cart Button (only shown if showAddToCartButton is true)
                            Button(action: {
                                // Handle add to cart - prevent tap propagation to card
                                // TODO: Add actual cart functionality if needed
                            }) {
                                VButton(
                                    title: VLocalizedString(VioTranslationKey.addToCart.rawValue),
                                    style: .primary,
                                    size: .medium,
                                    isLoading: false
                                ) {
                                    // Empty - action handled by Button wrapper
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(VioSpacing.md)
            }
            .background(adaptiveColors.surface)
            .cornerRadius(VioBorderRadius.large)
            .vioCardShadow(for: colorScheme)
            .padding(.horizontal, VioSpacing.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    /// Horizontal product card layout (image left, description right)
    private func horizontalProductCardView(product: Product) -> some View {
        Button(action: {
            // Track product click
            if let component = activeComponent {
                AnalyticsManager.shared.trackProductViewed(
                    productId: String(product.id),
                    productName: product.title,
                    productPrice: Double(product.price.amount),
                    productCurrency: product.price.currency_code,
                    source: "product_carousel",
                    componentId: component.id,
                    componentType: "product_carousel"
                )
            }
            
            // Handle tap - show product detail
            showingProductDetail = product
        }) {
            HStack(spacing: VioSpacing.sm) { // Reduced spacing
                // Image on the left (smaller)
                if let imageUrl = product.images.first?.url, let url = URL(string: imageUrl) {
                    ZStack {
                        // Background color for PNG images without background
                        RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                            .fill(imageBackgroundColor)
                            .frame(width: 90, height: 90)
                        
                        LoadedImage(
                            url: url,
                            placeholder: AnyView(RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                                .fill(adaptiveColors.surfaceSecondary)
                                .frame(width: 90, height: 90)
                                .overlay { VCustomLoader(style: .rotate, size: 24) }),
                            errorView: AnyView(RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                                .fill(adaptiveColors.surfaceSecondary)
                                .frame(width: 90, height: 90)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundColor(adaptiveColors.textSecondary)
                                })
                        )
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 90, height: 90)
                    }
                    .clipped()
                    .cornerRadius(VioBorderRadius.medium)
                } else {
                    RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                        .fill(imageBackgroundColor)
                        .frame(width: 90, height: 90) // Reduced image size
                }
                
                // Description on the right
                VStack(alignment: .leading, spacing: VioSpacing.xs) {
                    Text(product.title)
                        .font(.system(size: 13, weight: .semibold)) // Smaller title
                        .foregroundColor(adaptiveColors.textPrimary)
                        .lineLimit(2)
                    
                    if let brand = product.brand {
                        Text(brand)
                            .font(.system(size: 10, weight: .regular)) // Smaller brand
                            .foregroundColor(adaptiveColors.textSecondary)
                            .lineLimit(1)
                    }
                    
                    // Price (moved up, right after brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(product.price.displayAmount)
                            .font(.system(size: 14, weight: .bold)) // Smaller price
                            .foregroundColor(adaptiveColors.priceColor)
                        
                        if let compareAtAmount = product.price.displayCompareAtAmount {
                            Text(compareAtAmount)
                                .font(.system(size: 11, weight: .regular)) // Smaller compare price
                                .foregroundColor(adaptiveColors.textSecondary)
                                .strikethrough()
                        } else {
                            // Spacer to maintain consistent height
                            Text("")
                                .font(.system(size: 11, weight: .regular))
                                .opacity(0)
                        }
                    }
                    .frame(minHeight: 28)  // Fixed minimum height for consistent card sizes
                    
                    Spacer() // Push everything to top
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(VioSpacing.sm) // Reduced padding
            .background(adaptiveColors.surface)
            .cornerRadius(VioBorderRadius.large)
            .vioCardShadow(for: colorScheme)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var loadingView: some View {
        VStack(spacing: VioSpacing.md) {
            VCustomLoader(style: .rotate, size: 40)
            Text("Loading products...")
                .font(VioTypography.caption1)
                .foregroundColor(adaptiveColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VioSpacing.xl)
    }
    
    private var errorView: some View {
        VStack(spacing: VioSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(adaptiveColors.error)
            
            Text("Error loading products")
                .font(VioTypography.bodyBold)
                .foregroundColor(adaptiveColors.textPrimary)
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(VioTypography.caption1)
                    .foregroundColor(adaptiveColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, VioSpacing.lg)
            }
            
            Button {
                loadProductsIfNeeded()
            } label: {
                Text("Retry")
                    .font(VioTypography.caption1.weight(.semibold))
                    .foregroundColor(adaptiveColors.primary)
                    .padding(.horizontal, VioSpacing.md)
                    .padding(.vertical, VioSpacing.xs)
                    .background(adaptiveColors.primary.opacity(0.1))
                    .cornerRadius(VioBorderRadius.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VioSpacing.xl)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: VioSpacing.sm) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 32))
                .foregroundColor(adaptiveColors.textSecondary)
            
            Text("No products available")
                .font(VioTypography.bodyBold)
                .foregroundColor(adaptiveColors.textPrimary)
            
            Text("Products will appear here when available")
                .font(VioTypography.caption1)
                .foregroundColor(adaptiveColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VioSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VioSpacing.xl)
    }
    
    // MARK: - Skeleton View
    
    /// Skeleton loader shown while carousel is loading
    private var skeletonView: some View {
        // Use layout override if provided, otherwise use layout from config
        let currentLayout = layout ?? cachedConfig?.layout ?? "full"
        
        switch currentLayout {
        case "compact":
            return AnyView(skeletonViewCompact)
        case "horizontal":
            return AnyView(skeletonViewHorizontal)
        default: // "full"
            return AnyView(skeletonViewFull)
        }
    }
    
    /// Full layout skeleton (default)
    private var skeletonViewFull: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let horizontalPadding = VioSpacing.md * 2 // Padding on both sides
            let cardWidth = screenWidth - horizontalPadding
            let cardHeight = cardWidth * 1.3 // Balanced aspect ratio (approximately 3:4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VioSpacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        skeletonCardViewFull()
                            .frame(width: cardWidth, height: cardHeight)
                    }
                }
                .padding(.horizontal, VioSpacing.md)
            }
        }
    }
    
    /// Compact layout skeleton
    private var skeletonViewCompact: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let horizontalPadding = VioSpacing.md * 2 // Padding on both sides
            let spacing = VioSpacing.md // Spacing between cards (matches carouselContentCompact)
            // Calculate card width to show 2 cards at once
            let cardWidth = (screenWidth - horizontalPadding - spacing) / 2.0
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VioSpacing.md) {
                    ForEach(0..<4, id: \.self) { _ in
                        skeletonCardViewCompact()
                            .frame(width: cardWidth)
                    }
                }
                .padding(.horizontal, VioSpacing.md)
            }
        }
    }
    
    private func skeletonCardViewFull() -> some View {
        // Use exact same structure as fullLayoutProductCardView but with placeholders
        VStack(alignment: .leading, spacing: 0) {
            // Image skeleton - matches real card image aspect ratio
            Rectangle()
                .fill(adaptiveColors.surfaceSecondary)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .shimmerEffect()
            
            // Product Info skeleton - matches real card padding structure exactly
            VStack(alignment: .leading, spacing: VioSpacing.xs) {
                // Brand skeleton (optional, matches real card structure)
                RoundedRectangle(cornerRadius: VioBorderRadius.small)
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                    .frame(width: 60, height: 10)
                    .shimmerEffect()
                
                // Title skeleton
                RoundedRectangle(cornerRadius: VioBorderRadius.small)
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                    .frame(height: 16)
                    .shimmerEffect()
                
                RoundedRectangle(cornerRadius: VioBorderRadius.small)
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                    .frame(width: 120, height: 16)
                    .shimmerEffect()
                
                // Price skeleton
                HStack {
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                        .frame(width: 60, height: 16)
                        .shimmerEffect()
                    
                    Spacer()
                }
                .frame(minHeight: 32) // Matches real card minHeight
            }
            .padding(VioSpacing.md)
        }
        .background(adaptiveColors.surface)
        .cornerRadius(VioBorderRadius.large)
        .vioCardShadow(for: colorScheme)
        .padding(.horizontal, VioSpacing.md)
    }
    
    private func skeletonCardViewCompact() -> some View {
        // Use exact same structure as VProductCard.grid but with placeholders
        VStack(alignment: .leading, spacing: VioSpacing.sm) {
            // Image skeleton - matches VProductCard.grid image height (160)
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: VioBorderRadius.large)
                    .fill(adaptiveColors.surfaceSecondary)
                    .frame(height: 160)
                    .shimmerEffect()
            }
            
            // Product Info skeleton - matches VProductCard.grid structure exactly
            VStack(alignment: .leading, spacing: VioSpacing.xs) {
                // Brand skeleton (optional, matches VProductCard structure)
                RoundedRectangle(cornerRadius: VioBorderRadius.small)
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                    .frame(width: 50, height: 12)
                    .shimmerEffect()
                
                // Title skeleton
                RoundedRectangle(cornerRadius: VioBorderRadius.small)
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                    .frame(height: 16)
                    .shimmerEffect()
                
                RoundedRectangle(cornerRadius: VioBorderRadius.small)
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                    .frame(width: 100, height: 16)
                    .shimmerEffect()
                
                // Price skeleton
                RoundedRectangle(cornerRadius: VioBorderRadius.small)
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                    .frame(width: 60, height: 14)
                    .shimmerEffect()
            }
            .padding(VioSpacing.md)
        }
        .background(adaptiveColors.surface)
        .cornerRadius(VioBorderRadius.large)
        .vioCardShadow(for: colorScheme)
    }
    
    /// Horizontal layout skeleton
    private var skeletonViewHorizontal: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let cardWidth = screenWidth * 0.9 // 90% of screen width for horizontal cards
            let cardHeight: CGFloat = 110 // Reduced height for horizontal cards
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VioSpacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        skeletonHorizontalCardView()
                            .frame(width: cardWidth, height: cardHeight)
                    }
                }
                .padding(.horizontal, VioSpacing.md)
            }
        }
    }
    
    private func skeletonHorizontalCardView() -> some View {
        // Use exact same structure as horizontalProductCardView but with placeholders
        HStack(spacing: VioSpacing.sm) {
            // Image skeleton on the left - matches horizontalProductCardView (90x90)
            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                .fill(adaptiveColors.surfaceSecondary)
                .frame(width: 90, height: 90)
                .shimmerEffect()
            
            // Description skeleton on the right - matches horizontalProductCardView structure exactly
            VStack(alignment: .leading, spacing: VioSpacing.xs) {
                // Title skeleton
                RoundedRectangle(cornerRadius: VioBorderRadius.small)
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                    .frame(height: 16)
                    .shimmerEffect()
                
                RoundedRectangle(cornerRadius: VioBorderRadius.small)
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                    .frame(width: 100, height: 16)
                    .shimmerEffect()
                
                // Brand skeleton
                RoundedRectangle(cornerRadius: VioBorderRadius.small)
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                    .frame(width: 50, height: 12)
                    .shimmerEffect()
                
                // Price skeleton
                VStack(alignment: .leading, spacing: 2) {
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                        .frame(width: 50, height: 14)
                        .shimmerEffect()
                    
                    // Spacer for compare price
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(Color.clear)
                        .frame(height: 12)
                }
                .frame(minHeight: 28) // Matches real card minHeight
                
                Spacer() // Push everything to top
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(VioSpacing.sm)
        .background(adaptiveColors.surface)
        .cornerRadius(VioBorderRadius.large)
        .vioCardShadow(for: colorScheme)
    }
    
    // MARK: - Helper Methods
    
    /// Handle campaign change
    private func handleCampaignChange(_ campaign: Campaign?) {
        handleCampaignStateChange()
    }
    
    private func handleCampaignStateChange() {
        // Update cached config first
        updateCachedConfigIfNeeded()
        
        if shouldShow {
            loadProductsIfNeeded()
        } else {
            stopAutoScroll()
            viewModel.products = []
        }
    }
    
    private func handleComponentChange() {
        // Update cached config first
        updateCachedConfigIfNeeded()
        
        if shouldShow {
            loadProductsIfNeeded()
        } else {
            stopAutoScroll()
            viewModel.products = []
        }
    }
    
    /// Load products if config is available, otherwise wait for config
    private func loadProductsIfNeeded() {
        // If we have cached config, load products immediately
        if let cachedConfig = cachedConfig {
            loadProducts(with: cachedConfig)
        } else if config != nil {
            // Config exists but cachedConfig not created yet - update cache and load
            updateCachedConfigIfNeeded()
            if let cachedConfig = cachedConfig {
                loadProducts(with: cachedConfig)
            }
        } else {
            // No config yet - clear products and wait
            viewModel.products = []
        }
    }
    
    private func loadProducts(with cachedConfig: CachedConfig) {
        let sponsorId = activeComponent?.sponsorId
        Task {
            // Use cached Int product IDs (no conversion needed)
            await viewModel.loadProducts(
                productIds: cachedConfig.productIds,
                currency: VioConfiguration.shared.marketConfiguration.currencyCode,
                country: VioConfiguration.shared.marketConfiguration.countryCode,
                sponsorId: sponsorId
            )
        }
    }
    
    private func startAutoScroll(proxy: ScrollViewProxy) {
        guard let cachedConfig = cachedConfig,
              cachedConfig.shouldAutoPlay,
              viewModel.products.count > 1 else {
            return
        }
        
        stopAutoScroll()
        
        // Use cached interval (already converted to TimeInterval)
        let productCount = viewModel.products.count
        guard productCount > 0 else { return }
        
        // Store references safely
        let timerProxy = proxy
        let viewModelRef = viewModel
        
        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: cachedConfig.autoPlayInterval, repeats: true) { timer in
            // Access must be on main thread
            Task { @MainActor in
                guard viewModelRef.products.count > 0 else {
                    timer.invalidate()
                    return
                }
                
                let currentCount = viewModelRef.products.count
                guard currentCount > 0 else { return }
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    // Update index through ViewModel (safe)
                    let nextIndex = (viewModelRef.currentIndex + 1) % currentCount
                    viewModelRef.currentIndex = nextIndex
                    timerProxy.scrollTo(nextIndex, anchor: .leading)
                }
            }
        }
    }
    
    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
    
    /// Page indicators (dots) for carousel
    private var pageIndicators: some View {
        HStack(spacing: VioSpacing.xs) {
            ForEach(0..<viewModel.products.count, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentIndex ? adaptiveColors.primary : adaptiveColors.textSecondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.currentIndex)
            }
        }
        .padding(.vertical, VioSpacing.xs)
    }
    
    /// Page indicators for full layout (tighter spacing)
    private var pageIndicatorsFull: some View {
        HStack(spacing: 4) { // Fixed smaller spacing for full layout
            ForEach(0..<viewModel.products.count, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentIndex ? adaptiveColors.primary : adaptiveColors.textSecondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.currentIndex)
            }
        }
        .padding(.vertical, VioSpacing.xs)
    }
}

// MARK: - ViewModel

@MainActor
class VProductCarouselViewModel: ObservableObject {
    
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isMarketUnavailable: Bool = false
    /// Hide-on-failure flag — set true after a non-recoverable load
    /// error (auth failure, network outage, etc.). Combined with
    /// `products.isEmpty` it lets the view render EmptyView instead
    /// of a perpetual skeleton or an error CTA. Reset to false at the
    /// start of every load so any config change / WS event triggers a
    /// fresh attempt automatically.
    @Published var loadFailed: Bool = false
    @Published var currentIndex: Int = 0 // Move currentIndex to ViewModel for safe Timer access

    func loadProducts(productIds: [Int], currency: String, country: String, sponsorId: Int? = nil) async {
        guard VioConfiguration.shared.shouldUseSDK else {
            isMarketUnavailable = true
            isLoading = false
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        isMarketUnavailable = false
        loadFailed = false  // Fresh attempt — clear stale failure flag

        // Determine if we should load all products or filtered
        let idsToUse: [Int]? = productIds.isEmpty ? nil : productIds

        do {
            // Use ProductService to load products. sponsorId routes to the
            // per-sponsor commerce client (XXL's apiKey for an XXL placement,
            // etc.) — required for multi-sponsor placements where the
            // products live in a sponsor's catalog the primary doesn't share.
            products = try await ProductService.shared.loadProducts(
                productIds: idsToUse,
                currency: currency,
                country: country,
                sponsorId: sponsorId
            )

            if products.isEmpty {
                // No products found - will show empty state
            }

        } catch ProductServiceError.invalidConfiguration(let message) {
            errorMessage = message
            loadFailed = true
        } catch ProductServiceError.sdkError(let error) {
            if error.code == "NOT_FOUND" || error.status == 404 {
                isMarketUnavailable = true
                errorMessage = nil
            } else {
                errorMessage = error.message
                loadFailed = true
            }
        } catch ProductServiceError.networkError(let error) {
            errorMessage = error.localizedDescription
            loadFailed = true
        } catch {
            errorMessage = error.localizedDescription
            loadFailed = true
        }

        isLoading = false
    }
}

// MARK: - Scroll Offset Preference Key

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func shimmerEffect() -> some View {
        modifier(ShimmerEffectModifier())
    }
}

private struct ShimmerEffectModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    // Get adaptive colors for shimmer effect
                    let shimmerColor = VioColors.adaptive(for: .light).textPrimary.opacity(0.5)
                    LinearGradient(
                        colors: [
                            Color.clear,
                            shimmerColor,
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: (phase - 0.5) * geometry.size.width * 1.5)
                    .blendMode(.overlay)
                }
            )
            .onAppear {
                phase = 0
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1.0
                }
            }
    }
}

// `VRemoteImage` (format-agnostic remote image with SVG fallback) lives
// in its own file (`VRemoteImage.swift`) — extracted so VProductSpotlight
// and other placement views can render sponsor logos without
// duplicating the WKWebView fallback.

