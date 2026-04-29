import SwiftUI
import VioCore
import VioDesignSystem

/// Auto-configured Product Store component
/// Automatically loads configuration from active campaign
/// Usage: Just drag VProductStore() into your view - no parameters needed!
public struct VProductStore: View {
    
    // MARK: - Cached Config Values
    
    /// Internal structure to cache parsed config values
    /// This avoids recalculating layout and conversions on every render
    private struct CachedConfig {
        let mode: String
        let productIds: [Int]?
        /// Multi-sponsor entries — when present, takes priority over
        /// `productIds` and the SDK loads each product through its
        /// own sponsor's commerce credentials. Each tuple is
        /// (productIdInt, sponsorId).
        let products: [(productId: Int, sponsorId: Int)]?
        let displayType: String
        let columns: Int
        let gridItems: [GridItem] // Pre-computed grid layout
        /// Operator-set header title (above the grid). Empty/nil hides
        /// the header strip entirely.
        let title: String?
        /// Operator opt-in to render the placement's sponsor logo
        /// right-aligned in the header.
        let showSponsorLogo: Bool
        let configId: String // Used to detect config changes

        init(config: ProductStoreConfig) {
            self.mode = config.mode
            self.displayType = config.displayType
            self.columns = config.columns

            // Cache converted product IDs if available (String → Int)
            if let stringIds = config.productIds, !stringIds.isEmpty {
                self.productIds = stringIds.compactMap { Int($0) }
            } else {
                self.productIds = nil
            }

            // Multi-sponsor: parse `products[]` into (Int, Int) tuples.
            // Drop entries where productId isn't a valid Int (defensive).
            if let entries = config.products, !entries.isEmpty {
                self.products = entries.compactMap { entry in
                    guard let pid = Int(entry.productId) else { return nil }
                    return (productId: pid, sponsorId: entry.sponsorId)
                }
            } else {
                self.products = nil
            }

            // Pre-compute grid layout (expensive operation)
            self.gridItems = Array(repeating: GridItem(.flexible(), spacing: VioSpacing.md), count: config.columns)

            // Header opt-ins (default off; operator turns them on per
            // placement via the dashboard's customConfig).
            self.title = config.title
            self.showSponsorLogo = config.showSponsorLogo

            // Create unique identifier for this config (detects changes).
            // Includes the multi-sponsor entries so swapping the list
            // triggers a re-load.
            let productIdsString = config.productIds?.joined(separator: "-") ?? "all"
            let productsString = config.products?.map { "\($0.productId)@\($0.sponsorId)" }.joined(separator: ",") ?? ""
            self.configId = "\(config.mode)-\(productIdsString)-\(productsString)-\(config.displayType)-\(config.columns)-\(config.title ?? "")-\(config.showSponsorLogo)"
        }
    }

    // MARK: - Properties

    /// Optional component ID to identify a specific component
    /// If nil, uses the first matching component from the campaign
    private let componentId: String?

    /// Optional placement slot identifier (e.g. `"home_store"`).
    /// When provided, resolves the active component via
    /// `getActiveComponent(type:componentId:locationId:)` so the
    /// same `product_store` template can power multiple slots in
    /// one campaign without colliding on the template id.
    /// Sprint 2026-04-28 PM polish parity with VProductCarousel.
    private let locationId: String?

    /// Whether to show sponsor badge
    private let showSponsor: Bool

    /// Sponsor badge position: "topRight", "topLeft", "bottomRight", "bottomLeft"
    /// Default: "topRight"
    private let sponsorPosition: String

    @ObservedObject private var campaignManager = CampaignManager.shared
    @StateObject private var viewModel = VProductStoreViewModel()

    // Cache parsed config values - only recalculated when config changes
    @State private var cachedConfig: CachedConfig?
    @State private var currentConfigId: String?

    @SwiftUI.Environment(\.colorScheme) private var colorScheme: SwiftUI.ColorScheme

    // MARK: - Initializer

    public init(
        componentId: String? = nil,
        locationId: String? = nil,
        showSponsor: Bool = false,
        sponsorPosition: String? = nil
    ) {
        self.componentId = componentId
        self.locationId = locationId
        self.showSponsor = showSponsor
        self.sponsorPosition = sponsorPosition ?? "topRight"
    }

    // MARK: - Computed Properties

    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }

    /// Get active product store component from campaign
    private var activeComponent: Component? {
        campaignManager.getActiveComponent(type: "product_store", componentId: componentId, locationId: locationId)
    }
    
    /// Extract ProductStoreConfig from component
    private var config: ProductStoreConfig? {
        guard let component = activeComponent,
              case .productStore(let config) = component.config else {
            return nil
        }
        return config
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
        
        let productIdsString = config.productIds?.joined(separator: "-") ?? "all"
        let newConfigId = "\(config.mode)-\(productIdsString)-\(config.displayType)-\(config.columns)-\(config.title ?? "")-\(config.showSponsorLogo)"

        // Only recalculate if config actually changed
        if currentConfigId != newConfigId {
            cachedConfig = CachedConfig(config: config)
            currentConfigId = newConfigId
        }
    }
    
    /// Should show component
    private var shouldShow: Bool {
        // Check SDK availability
        guard VioConfiguration.shared.shouldUseSDK else {
            return false
        }

        // Hide-on-failure: stuck-skeleton guard. Sprint 2026-04-28 PM
        // Phase 2 polish — see VProductCarousel.shouldShow for the
        // shared rationale.
        if viewModel.loadFailed && viewModel.products.isEmpty {
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

        // Component must exist and be active
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
    
    public var body: some View {
        Group {
            if !shouldShow {
                EmptyView()
            } else if shouldHide {
                EmptyView()
            } else if shouldShowLoading {
                loadingView
            } else if shouldShowError {
                errorView
            } else if config != nil {
                if !products.isEmpty {
                    storeContent
                } else {
                    // Show empty state message
                    emptyStateView
                }
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .onChange(of: campaignManager.isCampaignActive) { _ in
            updateCachedConfigIfNeeded()
            handleCampaignStateChange()
        }
        .onChange(of: campaignManager.currentCampaign?.isPaused) { _ in
            updateCachedConfigIfNeeded()
            handleCampaignStateChange()
        }
        .onChange(of: activeComponent?.id) { _ in
            updateCachedConfigIfNeeded()
            handleComponentChange()
        }
        .onAppear {
            updateCachedConfigIfNeeded()
            handleComponentChange()
            
            // Track component view
            if let component = activeComponent, let config = cachedConfig {
                AnalyticsManager.shared.trackComponentView(
                    componentId: component.id,
                    componentType: "product_store",
                    componentName: component.name,
                    campaignId: campaignManager.currentCampaign?.id,
                    metadata: [
                        "display_type": config.displayType,
                        "columns": config.columns,
                        "product_count": products.count,
                        "has_product_ids": config.productIds != nil
                    ]
                )
            }
        }
    }
    
    // MARK: - Content Views
    
    /// Operator-controlled header strip (title + sponsor logo).
    /// Same opt-in pattern as VProductCarousel / VProductSpotlight —
    /// renders nothing when both `title` is empty and `showSponsorLogo`
    /// is false, so legacy hosts that haven't filled the new fields
    /// keep their existing layout untouched.
    @ViewBuilder
    private var placementHeader: some View {
        let title = (cachedConfig?.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let showLogo = cachedConfig?.showSponsorLogo == true
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

    private var storeContent: some View {
        let currentLogoUrl = campaignLogoUrl
        let shouldShowBadge = shouldShowSponsorBadge
        let position = sponsorPosition.isEmpty ? "topRight" : sponsorPosition

        // Determine if badge should be above or below content
        let isTopPosition = position == "topRight" || position == "topLeft"
        let isRightPosition = position == "topRight" || position == "bottomRight"

        return VStack(spacing: 0) {
            // Operator-controlled header (title + sponsor logo).
            // Renders nothing when neither opt-in is set.
            placementHeader

            // Badge container above content (if top position)
            if shouldShowBadge, let logoUrl = currentLogoUrl, isTopPosition {
                sponsorBadgeContainer(logoUrl: logoUrl, isRightPosition: isRightPosition)
            }
            
            Group {
                if let cachedConfig = cachedConfig {
                    if cachedConfig.displayType == "grid" {
                        gridView(columns: cachedConfig.gridItems)
                    } else {
                        listView
                    }
                }
            }
            
            // Badge container below content (if bottom position)
            if shouldShowBadge, let logoUrl = currentLogoUrl, !isTopPosition {
                sponsorBadgeContainer(logoUrl: logoUrl, isRightPosition: isRightPosition)
            }
        }
    }
    
    /// Sponsor badge container (like a div) positioned above or below content
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
    
    private func gridView(columns: [GridItem]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: VioSpacing.md) {
                ForEach(products) { product in
                    VProductCard(product: product, sponsorId: resolvedSponsorId(for: product.id))
                }
            }
            .padding(.horizontal, VioSpacing.md)
            .padding(.vertical, VioSpacing.md)
        }
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: VioSpacing.md) {
                ForEach(products) { product in
                    VProductCard(product: product, sponsorId: resolvedSponsorId(for: product.id))
                }
            }
            .padding(.horizontal, VioSpacing.md)
            .padding(.vertical, VioSpacing.md)
        }
    }

    /// Q4 (2026-04-30): resolve the sponsor that owns this product so the
    /// cart / Apple Pay flow uses per-sponsor commerce credentials. Multi-
    /// sponsor stores populate `viewModel.productSponsorMap` per item;
    /// legacy single-sponsor placements fall back to the placement's
    /// `sponsorId` (already set on `activeComponent` upstream).
    private func resolvedSponsorId(for productId: Int) -> Int? {
        if let mapped = viewModel.productSponsorMap[productId] {
            return mapped
        }
        return activeComponent?.sponsorId
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
                loadProducts()
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
    
    // MARK: - Helper Methods
    
    private func handleCampaignStateChange() {
        if shouldShow {
            loadProducts()
        } else {
            viewModel.products = []
        }
    }
    
    private func handleComponentChange() {
        if shouldShow {
            loadProducts()
        } else {
            viewModel.products = []
        }
    }
    
    private func loadProducts() {
        guard let cachedConfig = cachedConfig else {
            viewModel.products = []
            return
        }
        // Two paths:
        //   1. Multi-sponsor (`config.products[]`) — Sprint 2026-04-28
        //      PM Phase 2. Each entry has its own sponsorId so the
        //      store can surface SKUs across sponsors. ViewModel
        //      iterates and calls loadProduct per item with the
        //      right sponsor's commerce key.
        //   2. Legacy single-sponsor (`config.productIds[]` + the
        //      placement's `sponsorId`) — kept for back-compat with
        //      rows authored before multi-sponsor shipped.
        let placementSponsorId = activeComponent?.sponsorId

        Task {
            if let multiSponsorEntries = cachedConfig.products, !multiSponsorEntries.isEmpty {
                await viewModel.loadProductsMultiSponsor(
                    entries: multiSponsorEntries,
                    currency: VioConfiguration.shared.marketConfiguration.currencyCode,
                    country: VioConfiguration.shared.marketConfiguration.countryCode
                )
            } else {
                await viewModel.loadProducts(
                    mode: cachedConfig.mode,
                    productIds: cachedConfig.productIds,
                    currency: VioConfiguration.shared.marketConfiguration.currencyCode,
                    country: VioConfiguration.shared.marketConfiguration.countryCode,
                    sponsorId: placementSponsorId
                )
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class VProductStoreViewModel: ObservableObject {
    
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isMarketUnavailable: Bool = false
    /// Hide-on-failure flag — set when load throws a non-recoverable
    /// error. View's `shouldShow` falls through to EmptyView so the
    /// store disappears instead of showing a stuck skeleton.
    /// Reset on every load attempt.
    @Published var loadFailed: Bool = false
    /// productId → sponsorId. Populated by the multi-sponsor load
    /// path so the view layer can show a per-card sponsor badge and
    /// (future) route cart actions to the right per-sponsor commerce
    /// key. Empty for legacy single-sponsor loads.
    @Published var productSponsorMap: [Int: Int] = [:]

    /// Multi-sponsor load path. Iterates the operator-curated list,
    /// fetches each product through ITS sponsor's commerce key, and
    /// stamps `sponsorId` on the resulting Product so downstream
    /// (cart routing, sponsor-logo overlay on the card) knows where
    /// each SKU came from. Sprint 2026-04-28 PM Phase 2.
    ///
    /// Failures: a single product's fetch error (e.g. one sponsor
    /// offline) is logged and dropped — the rest of the list still
    /// renders. Only sets loadFailed when the ENTIRE list errors out
    /// (zero products loaded), so a flaky third-party sponsor
    /// doesn't tank the whole store.
    func loadProductsMultiSponsor(
        entries: [(productId: Int, sponsorId: Int)],
        currency: String,
        country: String
    ) async {
        guard VioConfiguration.shared.shouldUseSDK else {
            isMarketUnavailable = true
            isLoading = false
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        isMarketUnavailable = false
        loadFailed = false

        // Sequential per-product fetches. Each product uses its
        // own sponsor's commerce key (loadProduct routes via
        // VioConfiguration.commerce(forSponsorId:)). The visible
        // grid is correct end-to-end. Cart routing on tap currently
        // uses the SDK's active commerce client (last loaded
        // sponsor) — for multi-sponsor stores this is a known
        // limitation, tracked as a follow-up. The detail overlay
        // shows the right product regardless.
        var loaded: [Product] = []
        productSponsorMap.removeAll(keepingCapacity: true)
        for entry in entries {
            do {
                let p = try await ProductService.shared.loadProduct(
                    productId: entry.productId,
                    currency: currency,
                    country: country,
                    sponsorId: entry.sponsorId
                )
                loaded.append(p)
                // Side map: productId → sponsorId, used by the view's
                // tap handler / sponsor-logo overlay on the card.
                productSponsorMap[p.id] = entry.sponsorId
            } catch {
                VioLogger.warning(
                    "Multi-sponsor store: failed to load productId=\(entry.productId) sponsor=\(entry.sponsorId): \(error.localizedDescription)",
                    component: "VProductStore"
                )
                // Keep iterating — one bad sponsor shouldn't blank the store.
            }
        }

        products = loaded
        if loaded.isEmpty {
            // Every entry failed — surface as a load failure so
            // shouldShow short-circuits to EmptyView instead of an
            // empty grid stuck on "No products available".
            loadFailed = true
            errorMessage = "Multi-sponsor store: every product failed to load"
        }
        isLoading = false
    }

    func loadProducts(mode: String, productIds: [Int]?, currency: String, country: String, sponsorId: Int? = nil) async {
        guard VioConfiguration.shared.shouldUseSDK else {
            isMarketUnavailable = true
            isLoading = false
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        isMarketUnavailable = false
        loadFailed = false
        
        VioLogger.debug("Loading products - Mode: \(mode)", component: "VProductStore")
        
        do {
            // Product IDs are already converted to Int (cached)
            let hasValidIds = productIds != nil && !productIds!.isEmpty
            let shouldUseFiltered = mode == "filtered" && hasValidIds
            
            // Determine which IDs to use (if any)
            let idsToUse: [Int]?
            if shouldUseFiltered {
                VioLogger.debug("Filtered mode - Product IDs: \(productIds ?? [])", component: "VProductStore")
                idsToUse = productIds
            } else if mode == "filtered" && !hasValidIds {
                // Filtered mode but no IDs - fallback to all products
                VioLogger.warning("Filtered mode requires product IDs but none provided - falling back to all products", component: "VProductStore")
                idsToUse = nil
            } else {
                // All mode - load all products
                VioLogger.debug("All mode - Loading all products from channel", component: "VProductStore")
                idsToUse = nil
            }
            
            // Load products with determined IDs. sponsorId routes to
            // the per-sponsor commerce client (mirrors carousel /
            // spotlight / banner).
            products = try await ProductService.shared.loadProducts(
                productIds: idsToUse,
                currency: currency,
                country: country,
                sponsorId: sponsorId
            )

            // Fallback: If filtered mode returned 0 products, try loading all products instead
            if products.isEmpty && mode == "filtered" && hasValidIds {
                VioLogger.warning("No products found for filtered IDs: \(productIds ?? []) - falling back to all products", component: "VProductStore")

                // Retry with all products (no productIds filter)
                let allProducts: [Int]? = nil
                products = try await ProductService.shared.loadProducts(
                    productIds: allProducts,
                    currency: currency,
                    country: country,
                    sponsorId: sponsorId
                )
            }
            
            // Clear any previous error if we successfully loaded products
            if !products.isEmpty {
                errorMessage = nil
            } else if mode == "filtered" && (productIds == nil || productIds!.isEmpty) {
                // Only show error if we're in filtered mode and really have no IDs
                errorMessage = "No valid product IDs"
            }
            
        } catch ProductServiceError.invalidConfiguration(let message) {
            errorMessage = message
            loadFailed = true
            VioLogger.error("Invalid configuration: \(message)", component: "VProductStore")
        } catch ProductServiceError.sdkError(let error) {
            if error.code == "NOT_FOUND" || error.status == 404 {
                isMarketUnavailable = true
                errorMessage = nil
                VioLogger.warning("Market not available", component: "VProductStore")
            } else {
                errorMessage = error.message
                loadFailed = true
                VioLogger.error("Failed to load products: \(error.message)", component: "VProductStore")
            }
        } catch ProductServiceError.networkError(let error) {
            errorMessage = error.localizedDescription
            loadFailed = true
            VioLogger.error("Network error: \(error.localizedDescription)", component: "VProductStore")
        } catch {
            errorMessage = error.localizedDescription
            loadFailed = true
            VioLogger.error("Failed to load products: \(error.localizedDescription)", component: "VProductStore")
        }
        
        isLoading = false
    }
}

