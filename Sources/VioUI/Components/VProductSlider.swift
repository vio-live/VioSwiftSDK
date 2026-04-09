import SwiftUI
import VioCore
import VioDesignSystem

#if DEBUG
import VioTesting
#endif

/// Vio Product Slider Component
///
/// A horizontal scrolling component for displaying a collection of products.
/// Perfect for featured products, recommendations, or category showcases.
public struct VProductSlider: View {
    
    // MARK: - Layout Style
    public enum Layout {
        case compact    // Minimal cards with fixed width (120pt)
        case cards      // Grid-style cards with flexible width (180pt)
        case featured   // Hero-style cards for highlights (280pt)
        case wide       // Wide list-style cards for detailed browsing (320pt)
        case showcase   // Extra large premium cards for special promotions (360pt)
        case micro      // Tiny cards for dense recommendations (80pt)
        
        var cardVariant: VProductCard.Variant {
            switch self {
            case .compact: return .minimal
            case .cards: return .grid
            case .featured: return .hero
            case .wide: return .list
            case .showcase: return .hero
            case .micro: return .minimal
            }
        }
        
        var cardWidth: CGFloat? {
            switch self {
            case .compact: return 120
            case .cards: return 180
            case .featured: return 280
            case .wide: return 320
            case .showcase: return 360
            case .micro: return 80
            }
        }
        
        var spacing: CGFloat {
            switch self {
            case .compact: return VioSpacing.sm
            case .cards: return VioSpacing.md
            case .featured: return VioSpacing.lg
            case .wide: return VioSpacing.md
            case .showcase: return VioSpacing.xl
            case .micro: return VioSpacing.xs
            }
        }
        
        var showsDescription: Bool {
            switch self {
            case .featured, .showcase, .wide: return true
            case .compact, .cards, .micro: return false
            }
        }
        
        var showsBrand: Bool {
            switch self {
            case .micro: return false
            case .compact, .cards, .featured, .wide, .showcase: return true
            }
        }
        
        var allowsAddToCart: Bool {
            switch self {
            case .micro, .compact: return false
            case .cards, .featured, .wide, .showcase: return true
            }
        }
    }
    
    // MARK: - Properties
    private let title: String?
    private let manualProducts: [Product]?  // Products passed manually
    private let categoryId: Int?  // Optional category filter for auto-loading
    private let layout: Layout
    private let showSeeAll: Bool
    private let maxItems: Int?
    private let onProductTap: ((Product) -> Void)?
    private let onAddToCart: ((Product) -> Void)?
    private let onSeeAllTap: (() -> Void)?
    private let preferredCurrency: String?
    private let preferredCountry: String?
    private let showSponsor: Bool
    private let sponsorPosition: String
    
    // ViewModel for automatic product loading
    @StateObject private var viewModel = VProductSliderViewModel()
    
    // Observe CampaignManager for reactive updates
    @ObservedObject private var campaignManager = CampaignManager.shared
    
    // Environment for adaptive colors
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: SwiftUI.ColorScheme
    
    // Animation states
    @State private var addedProductId: Int?
    @State private var sliderScale: CGFloat = 1.0
    
    // MARK: - Initializer
    public init(
        title: String? = nil,
        products: [Product]? = nil,
        categoryId: Int? = nil,
        layout: Layout = .cards,
        showSeeAll: Bool = false,
        maxItems: Int? = nil,
        onProductTap: ((Product) -> Void)? = nil,
        onAddToCart: ((Product) -> Void)? = nil,
        onSeeAllTap: (() -> Void)? = nil,
        currency: String? = nil,
        country: String? = nil,
        showSponsor: Bool = false,
        sponsorPosition: String? = nil
    ) {
        self.title = title
        self.manualProducts = products
        self.categoryId = categoryId
        self.layout = layout
        self.showSeeAll = showSeeAll
        self.maxItems = maxItems
        self.onProductTap = onProductTap
        self.onAddToCart = onAddToCart
        self.onSeeAllTap = onSeeAllTap
        self.preferredCurrency = currency
        self.preferredCountry = country
        self.showSponsor = showSponsor
        self.sponsorPosition = sponsorPosition ?? "topRight"
    }
    
    // MARK: - Computed Properties
    
    /// Adaptive colors based on current color scheme
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    private var resolvedCurrency: String {
        preferredCurrency ?? VioConfiguration.shared.marketConfiguration.currencyCode
    }

    private var resolvedCountry: String {
        preferredCountry ?? VioConfiguration.shared.marketConfiguration.countryCode
    }

    private var autoLoadTaskKey: String {
        guard manualProducts == nil else { return "manual" }
        let categoryPart = categoryId.map(String.init) ?? "all"
        let campaignActive = campaignManager.isCampaignActive ? "active" : "inactive"
        let campaignPaused = campaignManager.currentCampaign?.isPaused == true ? "paused" : "running"
        return "\(resolvedCurrency)|\(resolvedCountry)|\(categoryPart)|\(campaignActive)|\(campaignPaused)"
    }
    
    /// Products to display - either manual or from ViewModel
    /// Returns empty array if component shouldn't show (follows same pattern as other components)
    private var products: [Product] {
        // If component shouldn't show, return empty array
        guard shouldShow else {
            return []
        }
        
        if let manual = manualProducts {
            return manual
        }
        return viewModel.products
    }
    
    /// Should show loading state
    private var shouldShowLoading: Bool {
        manualProducts == nil && viewModel.isLoading && viewModel.products.isEmpty
    }
    
    /// Should show error state
    private var shouldShowError: Bool {
        manualProducts == nil && viewModel.errorMessage != nil && viewModel.products.isEmpty && !viewModel.isMarketUnavailable
    }
    
    /// Should hide component (market unavailable)
    private var shouldHide: Bool {
        manualProducts == nil && viewModel.isMarketUnavailable
    }
    
    /// Should show component
    /// Follows the same pattern as VProductStore and VProductCarousel
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
        
        // If campaign has active components configured, check if this component type is active
        // Component type "product_slider" or "recommended_products" for recommended products
        if !campaignManager.activeComponents.isEmpty {
            // Check if product slider component is active
            let isActive = campaignManager.shouldShowComponent(type: "product_slider") ||
                          campaignManager.shouldShowComponent(type: "recommended_products") ||
                          campaignManager.shouldShowComponent(type: "products")
            return isActive
        }
        
        // If no components configured, show if campaign is active and not paused (default behavior)
        return true
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
            } else if !products.isEmpty {
                productSliderContent
            } else {
                // Empty placeholder to ensure onAppear fires
                Color.clear.frame(height: 1)
            }
        }
        .onChange(of: campaignManager.isCampaignActive) { isActive in
            // When campaign becomes inactive, clear products immediately
            if !isActive && manualProducts == nil {
                viewModel.clearProducts()
            }
        }
        .onChange(of: campaignManager.currentCampaign?.isPaused) { isPaused in
            // When campaign is paused, clear products immediately
            if isPaused == true && manualProducts == nil {
                viewModel.clearProducts()
            }
        }
        .onChange(of: shouldShow) { shouldShowValue in
            // When shouldShow changes to false, clear products immediately
            if !shouldShowValue && manualProducts == nil {
                viewModel.clearProducts()
            }
        }
        .task(id: autoLoadTaskKey) {
            guard manualProducts == nil else { return }
            
            // Don't load products if component shouldn't show
            guard shouldShow else {
                viewModel.clearProducts()
                return
            }
            
            await viewModel.loadProducts(
                categoryId: categoryId,
                currency: resolvedCurrency,
                country: resolvedCountry,
                forceRefresh: true
            )
        }
    }
    
    // MARK: - Content Views
    
    private var productSliderContent: some View {
        let currentLogoUrl = campaignLogoUrl
        let shouldShowBadge = shouldShowSponsorBadge
        let position = sponsorPosition.isEmpty ? "topRight" : sponsorPosition
        
        // Determine if badge should be above or below slider
        let isTopPosition = position == "topRight" || position == "topLeft"
        let isRightPosition = position == "topRight" || position == "bottomRight"
        
        return VStack(alignment: .leading, spacing: 0) {
            // Badge container above slider (if top position)
            if shouldShowBadge, let logoUrl = currentLogoUrl, isTopPosition {
                sponsorBadgeContainer(logoUrl: logoUrl, isRightPosition: isRightPosition)
            }
            
            VStack(alignment: .leading, spacing: VioSpacing.md) {
                // Header with title and see all button
                if let title = title {
                    headerView(title: title)
                }
                
                // Products slider
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: layout.spacing) {
                        ForEach(displayedProducts) { product in
                            productCardView(product: product)
                        }
                    }
                    .padding(.horizontal, VioSpacing.md)
                }
                .scaleEffect(sliderScale)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: sliderScale)
            }
            
            // Badge container below slider (if bottom position)
            if shouldShowBadge, let logoUrl = currentLogoUrl, !isTopPosition {
                sponsorBadgeContainer(logoUrl: logoUrl, isRightPosition: isRightPosition)
            }
        }
    }
    
    /// Sponsor badge container (like a div) positioned above or below slider
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
    
    private var loadingView: some View {
        VStack(spacing: VioSpacing.md) {
            VCustomLoader(style: .rotate, size: 40)
            Text(VLocalizedString(VioTranslationKey.loading.rawValue) + " products...")
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
            
            Text(VLocalizedString(VioTranslationKey.networkError.rawValue))
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
                Task {
                    await viewModel.reload(
                        categoryId: categoryId,
                        currency: resolvedCurrency,
                        country: resolvedCountry
                    )
                }
            } label: {
                Text(VLocalizedString(VioTranslationKey.retry.rawValue))
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
    
    // MARK: - Header View
    private func headerView(title: String) -> some View {
        HStack {
            Text(title)
                .font(VioTypography.headline)
                .foregroundColor(VioColors.textPrimary)
            
            Spacer()
            
            if showSeeAll {
                Button(action: { onSeeAllTap?() }) {
                    HStack(spacing: VioSpacing.xs) {
                        Text(VLocalizedString(VioTranslationKey.continueButton.rawValue))
                            .font(VioTypography.callout)
                            .foregroundColor(VioColors.primary)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(VioColors.primary)
                    }
                }
            }
        }
        .padding(.horizontal, VioSpacing.md)
    }
    
    // MARK: - Animation Functions
    
    private func animateAddToCart(for product: Product) {
        // Haptic feedback
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
        
        // Store the added product ID for visual feedback
        addedProductId = product.id
        
        // Slight scale animation for the entire slider
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            sliderScale = 1.02
        }
        
        // Return to normal scale
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                sliderScale = 1.0
            }
        }
        
        // Reset added product highlight after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                addedProductId = nil
            }
        }
        
        // Call the original callback
        onAddToCart?(product)
    }
    
    // MARK: - Product Card View
    private func productCardView(product: Product) -> some View {
        Group {
            if let cardWidth = layout.cardWidth {
                // Fixed width cards
                VProductCard(
                    product: product,
                    variant: layout.cardVariant,
                    showBrand: layout.showsBrand,
                    showDescription: layout.showsDescription,
                    onTap: { onProductTap?(product) },
                    onAddToCart: layout.allowsAddToCart ? { animateAddToCart(for: product) } : nil
                )
                .frame(width: cardWidth)
                .scaleEffect(addedProductId == product.id ? 1.05 : 1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: VioBorderRadius.large)
                        .stroke(VioColors.success, lineWidth: addedProductId == product.id ? 2 : 0)
                        .animation(.easeInOut(duration: 0.3), value: addedProductId)
                )
            } else {
                // Flexible width cards
                VProductCard(
                    product: product,
                    variant: layout.cardVariant,
                    showBrand: layout.showsBrand,
                    showDescription: layout.showsDescription,
                    onTap: { onProductTap?(product) },
                    onAddToCart: layout.allowsAddToCart ? { animateAddToCart(for: product) } : nil
                )
                .scaleEffect(addedProductId == product.id ? 1.05 : 1.0)
                .overlay(
                    RoundedRectangle(cornerRadius: VioBorderRadius.large)
                        .stroke(VioColors.success, lineWidth: addedProductId == product.id ? 2 : 0)
                        .animation(.easeInOut(duration: 0.3), value: addedProductId)
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    private var displayedProducts: [Product] {
        if let maxItems = maxItems {
            return Array(products.prefix(maxItems))
        }
        return products
    }
}

// MARK: - Convenience Initializers
extension VProductSlider {
    
    /// Featured products slider with hero layout
    public static func featured(
        title: String = "Featured Products",
        products: [Product],
        maxItems: Int = 5,
        onProductTap: ((Product) -> Void)? = nil,
        onAddToCart: ((Product) -> Void)? = nil,
        onSeeAllTap: (() -> Void)? = nil
    ) -> VProductSlider {
        return VProductSlider(
            title: title,
            products: products,
            layout: .featured,
            showSeeAll: true,
            maxItems: maxItems,
            onProductTap: onProductTap,
            onAddToCart: onAddToCart,
            onSeeAllTap: onSeeAllTap
        )
    }
    
    /// Recommendations slider with compact layout
    public static func recommendations(
        title: String = "You Might Like",
        products: [Product],
        maxItems: Int = 8,
        onProductTap: ((Product) -> Void)? = nil,
        onSeeAllTap: (() -> Void)? = nil
    ) -> VProductSlider {
        return VProductSlider(
            title: title,
            products: products,
            layout: .compact,
            showSeeAll: true,
            maxItems: maxItems,
            onProductTap: onProductTap,
            onSeeAllTap: onSeeAllTap
        )
    }
    
    /// Category products slider with card layout
    public static func category(
        title: String,
        products: [Product],
        maxItems: Int = 6,
        onProductTap: ((Product) -> Void)? = nil,
        onAddToCart: ((Product) -> Void)? = nil,
        onSeeAllTap: (() -> Void)? = nil
    ) -> VProductSlider {
        return VProductSlider(
            title: title,
            products: products,
            layout: .cards,
            showSeeAll: true,
            maxItems: maxItems,
            onProductTap: onProductTap,
            onAddToCart: onAddToCart,
            onSeeAllTap: onSeeAllTap
        )
    }
    
    /// Wide detailed slider for comprehensive product browsing
    public static func detailed(
        title: String,
        products: [Product],
        maxItems: Int = 4,
        onProductTap: ((Product) -> Void)? = nil,
        onAddToCart: ((Product) -> Void)? = nil,
        onSeeAllTap: (() -> Void)? = nil
    ) -> VProductSlider {
        return VProductSlider(
            title: title,
            products: products,
            layout: .wide,
            showSeeAll: true,
            maxItems: maxItems,
            onProductTap: onProductTap,
            onAddToCart: onAddToCart,
            onSeeAllTap: onSeeAllTap
        )
    }
    
    /// Premium showcase slider for high-end products
    public static func showcase(
        title: String = "Premium Collection",
        products: [Product],
        maxItems: Int = 3,
        onProductTap: ((Product) -> Void)? = nil,
        onAddToCart: ((Product) -> Void)? = nil,
        onSeeAllTap: (() -> Void)? = nil
    ) -> VProductSlider {
        return VProductSlider(
            title: title,
            products: products,
            layout: .showcase,
            showSeeAll: true,
            maxItems: maxItems,
            onProductTap: onProductTap,
            onAddToCart: onAddToCart,
            onSeeAllTap: onSeeAllTap
        )
    }
    
    /// Micro slider for dense product lists (footer, related items)
    public static func micro(
        title: String = "Related",
        products: [Product],
        maxItems: Int = 12,
        onProductTap: ((Product) -> Void)? = nil,
        onSeeAllTap: (() -> Void)? = nil
    ) -> VProductSlider {
        return VProductSlider(
            title: title,
            products: products,
            layout: .micro,
            showSeeAll: false,
            maxItems: maxItems,
            onProductTap: onProductTap,
            onSeeAllTap: onSeeAllTap
        )
    }
}

// MARK: - SwiftUI Previews
#if DEBUG
#Preview("Showcase Layout") {
    ScrollView {
        VProductSlider.showcase(
            title: "Premium Collection",
            products: Array(MockDataProvider.shared.sampleProducts.prefix(3)),
            onProductTap: { product in
                print("Showcase tapped: \(product.title)")
            },
            onAddToCart: { product in
                print("Add showcase to cart: \(product.title)")
            },
            onSeeAllTap: {
                print("See all showcase")
            }
        )
    }
}

#Preview("Wide Layout") {
    ScrollView {
        VProductSlider.detailed(
            title: "Detailed Browse",
            products: Array(MockDataProvider.shared.sampleProducts.prefix(4)),
            onProductTap: { product in
                print("Wide tapped: \(product.title)")
            },
            onAddToCart: { product in
                print("Add wide to cart: \(product.title)")
            },
            onSeeAllTap: {
                print("See all detailed")
            }
        )
    }
}

#Preview("Featured Layout") {
    ScrollView {
        VProductSlider.featured(
            title: "Featured Products",
            products: Array(MockDataProvider.shared.sampleProducts.prefix(5)),
            onProductTap: { product in
                print("Featured tapped: \(product.title)")
            },
            onAddToCart: { product in
                print("Add featured to cart: \(product.title)")
            },
            onSeeAllTap: {
                print("See all featured")
            }
        )
    }
}

#Preview("Cards Layout") {
    ScrollView {
        VProductSlider.category(
            title: "Electronics",
            products: Array(MockDataProvider.shared.sampleProducts.prefix(6)),
            onProductTap: { product in
                print("Cards tapped: \(product.title)")
            },
            onAddToCart: { product in
                print("Add cards to cart: \(product.title)")
            },
            onSeeAllTap: {
                print("See all electronics")
            }
        )
    }
}

#Preview("Compact Layout") {
    ScrollView {
        VProductSlider.recommendations(
            title: "You Might Like",
            products: Array(MockDataProvider.shared.sampleProducts.prefix(8)),
            onProductTap: { product in
                print("Compact tapped: \(product.title)")
            },
            onSeeAllTap: {
                print("See all recommendations")
            }
        )
    }
}

#Preview("Micro Layout") {
    ScrollView {
        VProductSlider.micro(
            title: "Related Items",
            products: Array(MockDataProvider.shared.sampleProducts.prefix(12)),
            onProductTap: { product in
                print("Micro tapped: \(product.title)")
            },
            onSeeAllTap: {
                print("See all related")
            }
        )
    }
}

#Preview("All Layouts Comparison") {
    ScrollView {
        VStack(spacing: VioSpacing.xl) {
            // Showcase
            VProductSlider.showcase(
                title: "Showcase (360pt)",
                products: Array(MockDataProvider.shared.sampleProducts.prefix(2)),
                onProductTap: { _ in },
                onAddToCart: { _ in }
            )
            
            // Wide
            VProductSlider.detailed(
                title: "Wide (320pt)",
                products: Array(MockDataProvider.shared.sampleProducts.prefix(3)),
                onProductTap: { _ in },
                onAddToCart: { _ in }
            )
            
            // Featured
            VProductSlider.featured(
                title: "Featured (280pt)",
                products: Array(MockDataProvider.shared.sampleProducts.prefix(4)),
                onProductTap: { _ in },
                onAddToCart: { _ in }
            )
            
            // Cards
            VProductSlider.category(
                title: "Cards (180pt)",
                products: Array(MockDataProvider.shared.sampleProducts.prefix(5)),
                onProductTap: { _ in },
                onAddToCart: { _ in }
            )
            
            // Compact
            VProductSlider.recommendations(
                title: "Compact (120pt)",
                products: Array(MockDataProvider.shared.sampleProducts.prefix(6)),
                onProductTap: { _ in }
            )
            
            // Micro
            VProductSlider.micro(
                title: "Micro (80pt)",
                products: Array(MockDataProvider.shared.sampleProducts.prefix(8)),
                onProductTap: { _ in }
            )
        }
        .padding(.vertical)
    }
}
#endif
