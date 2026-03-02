import SwiftUI
import VioCore
import VioUI
import VioDesignSystem

#if os(iOS)
import UIKit
#endif

/// Auto-configured Product Spotlight component
/// Automatically loads configuration from active campaign
/// 
/// **Usage:**
/// ```swift
/// // Basic usage - uses first product_spotlight component from backend
/// VProductSpotlight()
///
/// // Specific component ID - uses a specific product_spotlight component
/// VProductSpotlight(componentId: "product-spotlight-1")
/// VProductSpotlight(componentId: "product-spotlight-2")
/// ```
///
/// **Parameters:**
/// - `componentId: String?` - Optional component ID to identify a specific component. If `nil`, uses the first matching component.
/// - `variant: VProductCard.Variant?` - Optional card variant override. Options: `.grid`, `.list`, `.hero`, `.minimal`. If `nil`, uses `.hero` (default).
/// - `showAddToCartButton: Bool` - Whether to show the "Add to Cart" button in hero variant. Default: `true`. Button only shows if product has no variants.
///
/// **Backend Configuration (from API):**
/// The component reads configuration from `GET /api/campaigns/{campaignId}/components`:
/// ```json
/// {
///   "components": [{
///     "componentId": "product-spotlight-1",
///     "status": "active",
///     "customConfig": {
///       "productId": "408841",
///       "highlightText": "Feature Product"
///     }
///   }]
/// }
/// ```
///
/// **Configuration Properties:**
/// - `productId: String` - Product ID to display
/// - `highlightText: String?` - Optional text to display as a badge/highlight
///
/// **Features:**
/// - ✅ Skeleton loader while loading
/// - ✅ Multiple card variants (hero, grid, list, minimal)
/// - ✅ Highlight badge with custom text
/// - ✅ Clickable card opens product detail overlay
public struct VProductSpotlight: View {
    
    // MARK: - Properties
    
    /// Optional component ID to identify a specific component
    /// If nil, uses the first matching component from the campaign
    private let componentId: String?
    
    /// Optional card variant override for demo/testing
    /// If nil, uses .hero (default)
    private let variant: VProductCard.Variant?
    
    /// Whether to show the "Add to Cart" button in hero variant
    /// Default: true. Button only shows if product has no variants.
    private let showAddToCartButton: Bool
    
    /// Whether to show sponsor badge
    private let showSponsor: Bool
    
    /// Sponsor badge position: "topRight", "topLeft", "bottomRight", "bottomLeft"
    /// Default: "topRight"
    private let sponsorPosition: String
    
    @ObservedObject private var campaignManager = CampaignManager.shared
    @StateObject private var viewModel = VProductSpotlightViewModel()
    
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: SwiftUI.ColorScheme
    @EnvironmentObject private var cartManager: CartManager
    
    @State private var showingProductDetail: Product?
    
    // Cache parsed config values - only recalculated when config changes
    @State private var cachedProductId: String?
    @State private var cachedHighlightText: String?
    @State private var currentConfigId: String?
    
    // Computed colors based on current color scheme
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    // MARK: - Initializer
    
    public init(componentId: String? = nil, variant: VProductCard.Variant? = nil, showAddToCartButton: Bool = true, showSponsor: Bool = false, sponsorPosition: String? = nil) {
        self.componentId = componentId
        self.variant = variant
        self.showAddToCartButton = showAddToCartButton
        self.showSponsor = showSponsor
        self.sponsorPosition = sponsorPosition ?? "topRight"
    }
    
    // MARK: - Computed Properties
    
    /// Get active product spotlight component from campaign
    private var activeComponent: Component? {
        campaignManager.getActiveComponent(type: "product_spotlight", componentId: componentId)
    }
    
    /// Extract ProductSpotlightConfig from component
    private var config: ProductSpotlightConfig? {
        guard let component = activeComponent,
              case .productSpotlight(let config) = component.config else {
            return nil
        }
        return config
    }
    
    /// Update cached config when config changes
    private func updateCachedConfigIfNeeded() {
        guard let config = config else {
            if cachedProductId != nil {
                cachedProductId = nil
                cachedHighlightText = nil
                currentConfigId = nil
            }
            return
        }
        
        let newConfigId = "\(config.productId)-\(config.highlightText ?? "")"
        
        // Only recalculate if config actually changed
        if currentConfigId != newConfigId {
            cachedProductId = config.productId
            cachedHighlightText = config.highlightText
            currentConfigId = newConfigId
        }
    }
    
    /// Should show component
    private var shouldShow: Bool {
        // Check SDK availability
        guard VioConfiguration.shared.shouldUseSDK else {
            return false
        }
        
        // Check campaign state
        let campaignId = VioConfiguration.shared.liveShowConfiguration.campaignId
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
    
    /// Product to display
    private var product: Product? {
        viewModel.product
    }
    
    /// Should show loading state
    private var shouldShowLoading: Bool {
        viewModel.isLoading && viewModel.product == nil
    }
    
    /// Should show error state
    private var shouldShowError: Bool {
        viewModel.errorMessage != nil && viewModel.product == nil && !viewModel.isMarketUnavailable
    }
    
    /// Should hide component (market unavailable)
    private var shouldHide: Bool {
        viewModel.isMarketUnavailable
    }
    
    /// Get campaign logo URL from VioConfiguration (evita EXC_BAD_ACCESS en campaignManager.currentCampaign?.campaignLogo)
    private var campaignLogoUrl: String? {
        VioConfiguration.shared.dynamicBrandConfig?.logoUrl
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
            } else if let config = config {
                ZStack {
                    // Skeleton - fades out when content is ready
                    skeletonView
                        .opacity(shouldShowLoading ? 1.0 : 0.0)
                        .animation(.easeInOut(duration: 0.3), value: shouldShowLoading)
                    
                    // Error view
                    if shouldShowError {
                        errorView
                            .opacity(shouldShowLoading ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: shouldShowLoading)
                    }
                    
                    // Content - fades in when ready
                    if let product = product {
                        spotlightContentView(product: product, highlightText: cachedHighlightText)
                            .opacity(shouldShowLoading ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: shouldShowLoading)
                    } else if !shouldShowLoading && !shouldShowError {
                        emptyStateView
                            .opacity(shouldShowLoading ? 0.0 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: shouldShowLoading)
                    }
                }
            }
        }
        .onAppear {
            updateCachedConfigIfNeeded()
            loadProductIfNeeded()
        }
        .onChange(of: campaignManager.activeComponents.count) { _ in
            updateCachedConfigIfNeeded()
            loadProductIfNeeded()
        }
        .onChange(of: cachedProductId) { _ in
            loadProductIfNeeded()
        }
        .task {
            // Small delay to ensure campaign components are loaded
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            updateCachedConfigIfNeeded()
            loadProductIfNeeded()
        }
    }
    
    // MARK: - Content Views
    
    /// Main spotlight content view with product card and highlight badge
    private func spotlightContentView(product: Product, highlightText: String?) -> some View {
        let currentLogoUrl = campaignLogoUrl
        let shouldShowBadge = shouldShowSponsorBadge
        let position = sponsorPosition.isEmpty ? "topRight" : sponsorPosition
        
        // Determine if badge should be above or below content
        let isTopPosition = position == "topRight" || position == "topLeft"
        let isRightPosition = position == "topRight" || position == "bottomRight"
        
        return VStack(spacing: 0) {
            // Badge container above content (if top position)
            if shouldShowBadge, let logoUrl = currentLogoUrl, isTopPosition {
                sponsorBadgeContainer(logoUrl: logoUrl, isRightPosition: isRightPosition)
            }
            
            VStack(spacing: VioSpacing.md) {
                // Highlight badge (if provided) - only show for hero variant
                if let highlightText = highlightText, !highlightText.isEmpty, variant == nil || variant == .hero {
                    Text(highlightText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(adaptiveColors.surface)
                        .padding(.horizontal, VioSpacing.md)
                        .padding(.vertical, VioSpacing.xs)
                        .background(
                            Capsule()
                                .fill(adaptiveColors.primary)
                        )
                        .padding(.horizontal, VioSpacing.md)
                }
                
                // Use custom hero layout if hero variant, otherwise use VProductCard
                if variant == nil || variant == .hero {
                    customHeroLayout(product: product)
                        .padding(.horizontal, VioSpacing.md)
                } else {
                    // For other variants, use VProductCard directly
                    VProductCard(
                        product: product,
                        variant: variant!,
                        showBrand: VioConfiguration.shared.uiConfiguration.showProductBrands,
                        showDescription: VioConfiguration.shared.uiConfiguration.showProductDescriptions,
                        showProductDetail: true
                    )
                    .padding(.horizontal, VioSpacing.md)
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
    
    /// Custom hero layout with smaller fonts and conditional Add to Cart button
    private func customHeroLayout(product: Product) -> some View {
        Button(action: {
            showingProductDetail = product
        }) {
            VStack(alignment: .leading, spacing: VioSpacing.md) {
                // Large Product Images with pagination
                productImagesView(product: product, height: 300)
                
                VStack(alignment: .leading, spacing: VioSpacing.sm) {
                    if VioConfiguration.shared.uiConfiguration.showProductBrands, let brand = product.brand {
                        Text(brand)
                            .font(.system(size: 11, weight: .medium)) // Smaller than default
                            .foregroundColor(adaptiveColors.textSecondary)
                            .textCase(.uppercase)
                    }
                    
                    Text(product.title)
                        .font(.system(size: 18, weight: .semibold)) // Smaller than VioTypography.title2
                        .foregroundColor(adaptiveColors.textPrimary)
                        .lineLimit(3)
                    
                    if VioConfiguration.shared.uiConfiguration.showProductDescriptions, let description = product.description {
                        Text(description)
                            .font(.system(size: 14, weight: .regular)) // Smaller than VioTypography.body
                            .foregroundColor(adaptiveColors.textSecondary)
                            .lineLimit(3)
                    }
                    
                    HStack {
                        // Price
                        VStack(alignment: .leading, spacing: 2) {
                            Text(product.price.displayAmount)
                                .font(.system(size: 18, weight: .semibold)) // Smaller than VioTypography.title3
                                .foregroundColor(adaptiveColors.priceColor)
                            
                            if let compareAtAmount = product.price.displayCompareAtAmount {
                                Text(compareAtAmount)
                                    .font(.system(size: 14, weight: .regular)) // Smaller than VioTypography.caption1
                                    .foregroundColor(adaptiveColors.textSecondary)
                                    .strikethrough()
                            } else {
                                // Spacer to maintain consistent height
                                Text("")
                                    .font(.system(size: 14, weight: .regular))
                                    .opacity(0)
                            }
                        }
                        .frame(minHeight: 40)  // Fixed minimum height for consistent card sizes
                        
                        Spacer()
                        
                        // Add to Cart button - only show if no variants and showAddToCartButton is true
                        if showAddToCartButton && product.variants.isEmpty && (product.quantity ?? 0) > 0 {
                            Button(action: {
                                // Stop propagation to parent button
                                Task {
                                    await cartManager.addProduct(product, quantity: 1)
                                }
                            }) {
                                Text(VLocalizedString(VioTranslationKey.addToCart.rawValue))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(adaptiveColors.surface)
                                    .padding(.horizontal, VioSpacing.md)
                                    .padding(.vertical, VioSpacing.sm)
                                    .background(adaptiveColors.primary)
                                    .cornerRadius(VioBorderRadius.medium)
                            }
                            .buttonStyle(PlainButtonStyle()) // Prevent double tap
                        }
                    }
                }
                .padding(VioSpacing.md) // Smaller padding than VioSpacing.lg
            }
            .background(adaptiveColors.surface)
            .cornerRadius(VioBorderRadius.xl)
            .vioCardShadow(for: colorScheme)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(item: $showingProductDetail) { product in
            VProductDetailOverlay(
                product: product,
                onDismiss: {
                    showingProductDetail = nil
                }
            )
        }
    }
    
    /// Product images view with pagination support
    private func productImagesView(product: Product, height: CGFloat) -> some View {
        let sortedImages = product.images.sorted { first, second in
            let firstPriority = (first.order == 0 || first.order == 1) ? first.order : Int.max
            let secondPriority = (second.order == 0 || second.order == 1) ? second.order : Int.max
            if firstPriority != secondPriority {
                return firstPriority < secondPriority
            }
            return first.order < second.order
        }
        
        let primaryImageUrl = sortedImages.first?.url
        
        return VStack(spacing: 0) {
            if sortedImages.count > 1 {
                TabView {
                    ForEach(sortedImages, id: \.id) { image in
                        productImageView(imageUrl: image.url, height: height)
                            .tag(image.id)
                    }
                }
#if os(iOS) || os(tvOS) || os(watchOS)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
#endif
                .frame(height: height)
            } else {
                productImageView(imageUrl: primaryImageUrl, height: height)
            }
        }
        .cornerRadius(VioBorderRadius.medium)
    }
    
    /// Single product image view
    private func productImageView(imageUrl: String?, height: CGFloat) -> some View {
        let imageURL = URL(string: imageUrl ?? "")
        
        return LoadedImage(
            url: imageURL,
            placeholder: AnyView(Rectangle()
                .fill(adaptiveColors.background)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(adaptiveColors.textSecondary)
                )),
            errorView: AnyView(Rectangle()
                .fill(adaptiveColors.background)
                .overlay(
                    VStack(spacing: VioSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundColor(adaptiveColors.error)
                        Text(VLocalizedString(VioTranslationKey.noImageAvailable.rawValue))
                            .font(VioTypography.caption1)
                            .foregroundColor(adaptiveColors.error)
                    }
                ))
        )
        .aspectRatio(contentMode: .fill)
        .frame(height: height)
        .clipped()
        .cornerRadius(VioBorderRadius.medium)
    }
    
    // MARK: - Skeleton View
    
    /// Skeleton loader shown while product is loading
    private var skeletonView: some View {
        VStack(spacing: VioSpacing.md) {
            // Highlight badge skeleton
            RoundedRectangle(cornerRadius: VioBorderRadius.circle)
                .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                .frame(width: 120, height: 28)
                .padding(.horizontal, VioSpacing.md)
                .shimmerEffect()
            
            // Hero card skeleton
            VStack(spacing: VioSpacing.lg) {
                // Image skeleton
                RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                    .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                    .frame(height: 300)
                    .shimmerEffect()
                
                // Content skeleton
                VStack(alignment: .leading, spacing: VioSpacing.sm) {
                    // Brand skeleton
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                        .frame(width: 100, height: 12)
                        .shimmerEffect()
                    
                    // Title skeleton
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                        .frame(height: 20)
                        .shimmerEffect()
                    
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                        .frame(width: 200, height: 20)
                        .shimmerEffect()
                    
                    // Description skeleton
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                        .frame(height: 14)
                        .shimmerEffect()
                    
                    RoundedRectangle(cornerRadius: VioBorderRadius.small)
                        .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                        .frame(width: 250, height: 14)
                        .shimmerEffect()
                    
                    // Price and button skeleton
                    HStack {
                        RoundedRectangle(cornerRadius: VioBorderRadius.small)
                            .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                            .frame(width: 80, height: 24)
                            .shimmerEffect()
                        
                        Spacer()
                        
                        RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                            .fill(adaptiveColors.surfaceSecondary.opacity(0.6))
                            .frame(width: 120, height: 44)
                            .shimmerEffect()
                    }
                }
                .padding(VioSpacing.lg)
            }
            .background(adaptiveColors.surface)
            .cornerRadius(VioBorderRadius.xl)
            .vioCardShadow(for: colorScheme)
            .padding(.horizontal, VioSpacing.md)
        }
        .padding(.vertical, VioSpacing.md)
    }
    
    // MARK: - Error & Empty States
    
    private var errorView: some View {
        VStack(spacing: VioSpacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(adaptiveColors.error)
            
            Text("Error loading product")
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
                loadProductIfNeeded()
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
        .padding(.horizontal, VioSpacing.md)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: VioSpacing.sm) {
            Image(systemName: "photo")
                .font(.system(size: 32))
                .foregroundColor(adaptiveColors.textSecondary)
            
            Text("Product not available")
                .font(VioTypography.bodyBold)
                .foregroundColor(adaptiveColors.textPrimary)
            
            Text("The product will appear here when available")
                .font(VioTypography.caption1)
                .foregroundColor(adaptiveColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VioSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VioSpacing.xl)
        .padding(.horizontal, VioSpacing.md)
    }
    
    // MARK: - Helper Methods
    
    /// Load product if needed
    private func loadProductIfNeeded() {
        guard let productIdString = cachedProductId,
              let productId = Int(productIdString) else {
            return
        }
        
        let currency = VioConfiguration.shared.marketConfiguration.currencyCode
        let country = VioConfiguration.shared.marketConfiguration.countryCode
        
        Task {
            await viewModel.loadProduct(
                productId: productId,
                currency: currency,
                country: country
            )
        }
    }
}

// MARK: - View Model

/// ViewModel for VProductSpotlight
@MainActor
private class VProductSpotlightViewModel: ObservableObject {
    @Published var product: Product?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isMarketUnavailable: Bool = false
    
    func loadProduct(productId: Int, currency: String, country: String) async {
        guard VioConfiguration.shared.shouldUseSDK else {
            isMarketUnavailable = true
            isLoading = false
            return
        }
        
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        isMarketUnavailable = false
        
        do {
            // Use ProductService to load product
            product = try await ProductService.shared.loadProduct(
                productId: productId,
                currency: currency,
                country: country
            )
            
        } catch ProductServiceError.productNotFound(let id) {
            errorMessage = "Product not found"
            VioLogger.warning("Product not found for ID: \(id) - Currency: \(currency), Country: \(country)", component: "VProductSpotlight")
        } catch ProductServiceError.invalidConfiguration(let message) {
            errorMessage = "Invalid configuration"
            VioLogger.error("Invalid configuration: \(message)", component: "VProductSpotlight")
        } catch ProductServiceError.sdkError(let error) {
            if error.code == "NOT_FOUND" || error.status == 404 {
                isMarketUnavailable = true
                errorMessage = nil
                VioLogger.warning("Market not available", component: "VProductSpotlight")
            } else {
                errorMessage = error.message
                VioLogger.error("Error loading product: \(error.message)", component: "VProductSpotlight")
            }
        } catch {
            errorMessage = "Failed to load product"
            VioLogger.error("Unexpected error: \(error.localizedDescription)", component: "VProductSpotlight")
        }
        
        isLoading = false
    }
}

// MARK: - Shimmer Effect Modifier

/// Shimmer effect modifier for skeleton loaders
private struct ShimmerEffectModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.clear,
                            VioColors.adaptive(for: .light).textPrimary.opacity(0.5),
                            Color.clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                }
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1.0
                }
            }
    }
}

private extension View {
    func shimmerEffect() -> some View {
        modifier(ShimmerEffectModifier())
    }
}

