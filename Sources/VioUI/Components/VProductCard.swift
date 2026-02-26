import SwiftUI
import VioCore
import VioDesignSystem

#if os(iOS)
import UIKit
#endif

#if DEBUG
import VioTesting
#endif

/// Vio Product Card Component
/// 
/// A flexible product card that adapts to different layouts and use cases.
/// Uses the modular design system for consistent styling.
///
/// **Usage:**
/// ```swift
/// // Basic usage (grid layout)
/// VProductCard(product: product)
///
/// // Different variants
/// VProductCard(product: product, variant: .list)
/// VProductCard(product: product, variant: .hero)
/// VProductCard(product: product, variant: .minimal)
/// 
/// // With customization
/// VProductCard(product: product, variant: .grid, showBrand: false)
/// ```
public struct VProductCard: View {
    
    // MARK: - Variant Types
    public enum Variant {
        case grid      // Default: Vertical layout for product grids
        case list      // Horizontal layout for search results
        case hero      // Large featured product display
        case minimal   // Compact for carousels/suggestions
    }
    
    // MARK: - Properties
    private let product: Product
    private let variant: Variant
    private let showBrand: Bool
    private let showDescription: Bool
    private let showProductDetail: Bool
    private let onTap: (() -> Void)?
    private let onAddToCart: (() -> Void)?
    private let imageBackgroundColor: Color?
    
    // Environment for adaptive colors
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: SwiftUI.ColorScheme
    
    // Computed colors based on current color scheme
    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }
    
    
    // Animation states
    @State private var isAddingToCart = false
    @State private var showCheckmark = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var showingProductDetail = false
    
    // MARK: - Initializer
    public init(
        product: Product,
        variant: Variant = .grid,
        showBrand: Bool = VioConfiguration.shared.uiConfiguration.showProductBrands,
        showDescription: Bool = VioConfiguration.shared.uiConfiguration.showProductDescriptions,
        showProductDetail: Bool = true,
        onTap: (() -> Void)? = nil,
        onAddToCart: (() -> Void)? = nil,
        imageBackgroundColor: Color? = nil  // Optional background color for product images (default: nil)
    ) {
        self.product = product
        self.variant = variant
        self.showBrand = showBrand
        self.showDescription = showDescription
        self.showProductDetail = showProductDetail
        self.onTap = onTap
        self.onAddToCart = onAddToCart
        self.imageBackgroundColor = imageBackgroundColor
    }
    
    // MARK: - Body
    public var body: some View {
        Button(action: handleTap) {
            switch variant {
            case .grid:
                gridLayout
            case .list:
                listLayout
            case .hero:
                heroLayout
            case .minimal:
                minimalLayout
            }
        }
        .buttonStyle(PlainButtonStyle())
        
        .sheet(isPresented: $showingProductDetail) {
            VProductDetailOverlay(
                product: product,
                onDismiss: {
                    showingProductDetail = false
                }
            )
            
        }
    }
    
    // MARK: - Layout Variants
    
    /// Grid Layout - Vertical card for product catalogs
    private var gridLayout: some View {
        VStack(alignment: .leading, spacing: VioSpacing.sm) {
            // Product Images with pagination
            ZStack(alignment: .topTrailing) {
                productImagesView(height: 160, showPagination: sortedImages.count > 1)
                
                // Discount badge (calculated dynamically if product has compareAt price)
                if VioConfiguration.shared.uiConfiguration.showDiscountBadge,
                   let discount = calculateDiscountPercentage() {
                    discountBadge(text: "-\(discount)%")
                }
            }
            
            // Product Info
            VStack(alignment: .leading, spacing: VioSpacing.xs) {
                if showBrand, let brand = product.brand {
                    Text(brand)
                        .font(VioTypography.caption1)
                        .foregroundColor(adaptiveColors.textSecondary)
                        .lineLimit(1)
                }
                
                Text(product.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(adaptiveColors.textPrimary)
                    .lineLimit(2)
                
                if showDescription, let description = product.description {
                    Text(description)
                        .font(VioTypography.caption1)
                        .foregroundColor(adaptiveColors.textSecondary)
                        .lineLimit(2)
                }
                
                // Price only (quick add removed - products have variations)
                priceView
            }
            .padding(VioSpacing.md)
        }
        .background(adaptiveColors.surface)
        .cornerRadius(VioBorderRadius.large)
        .vioCardShadow(for: colorScheme)
    }
    
    /// List Layout - Horizontal card for search results
    private var listLayout: some View {
        HStack(spacing: VioSpacing.sm) {
            // Product Image (smaller for list)
            productImageView(height: 70, width: 70)
            
            // Product Info
            VStack(alignment: .leading, spacing: VioSpacing.xs) {
                if showBrand, let brand = product.brand {
                    Text(brand)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(adaptiveColors.textSecondary)
                        .lineLimit(1)
                }
                
                Text(product.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(adaptiveColors.textPrimary)
                    .lineLimit(2)
                
                if showDescription, let description = product.description {
                    Text(description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(adaptiveColors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Price only (quick add removed - products have variations)
                priceView
            }
            
            Spacer()
        }
        .padding(VioSpacing.sm)
        .background(adaptiveColors.surface)
        .cornerRadius(VioBorderRadius.small)
        .vioCardShadow(for: colorScheme)
    }
    
    /// Hero Layout - Large featured product
    private var heroLayout: some View {
        VStack(alignment: .leading, spacing: VioSpacing.lg) {
            // Large Product Images with full pagination
            productImagesView(height: 300, showPagination: sortedImages.count > 1)
            
            VStack(alignment: .leading, spacing: VioSpacing.sm) {
                if showBrand, let brand = product.brand {
                    Text(brand)
                        .font(VioTypography.caption1)
                        .foregroundColor(adaptiveColors.textSecondary)
                        .textCase(.uppercase)
                }
                
                Text(product.title)
                    .font(VioTypography.title2)
                    .foregroundColor(adaptiveColors.textPrimary)
                    .lineLimit(3)
                
                if showDescription, let description = product.description {
                    Text(description)
                        .font(VioTypography.body)
                        .foregroundColor(adaptiveColors.textSecondary)
                        .lineLimit(3)
                }
                
                HStack {
                    priceView
                    Spacer()
                    VButton(
                        title: showCheckmark ? VLocalizedString(VioTranslationKey.success.rawValue) : VLocalizedString(VioTranslationKey.addToCart.rawValue),
                        style: .primary,
                        size: .large,
                        isLoading: isAddingToCart,
                        icon: showCheckmark ? "checkmark" : nil
                    ) {
                        animateAddToCart()
                    }
                    .disabled(!isInStock || isAddingToCart)
                    .scaleEffect(buttonScale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: buttonScale)
                }
            }
            .padding(VioSpacing.lg)
        }
        .background(adaptiveColors.surface)
        .cornerRadius(VioBorderRadius.xl)
        .vioCardShadow(for: colorScheme)
    }
    
    /// Minimal Layout - Compact for carousels
    private var minimalLayout: some View {
        VStack(alignment: .leading, spacing: VioSpacing.xs) {
            // Compact Product Image (smaller)
            productImageView(height: 80, width: 100)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(product.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(adaptiveColors.textPrimary)
                    .lineLimit(2)
                
                priceView
            }
            .padding(VioSpacing.xs)
        }
        .frame(width: 100, height: 140)
        .background(adaptiveColors.surface)
        .cornerRadius(VioBorderRadius.small)
        .vioCardShadow(for: colorScheme)
    }
    
    // MARK: - Image Components
    
    /// Multiple images view with pagination for grid and hero variants
    private func productImagesView(height: CGFloat, showPagination: Bool) -> some View {
        VStack(spacing: 0) {
            if sortedImages.count > 1 && showPagination {
                // Multiple images with TabView for pagination
                TabView {
                    ForEach(sortedImages, id: \.id) { image in
                        productImageView(
                            height: height,
                            imageUrl: image.url
                        )
                        .tag(image.id)
                    }
                }
#if os(iOS) || os(tvOS) || os(watchOS)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
#endif
                .frame(height: height)
            } else {
                // Single image or fallback
                productImageView(height: height)
            }
        }
        .cornerRadius(VioBorderRadius.medium)
    }
    
    /// Single image view with error handling and placeholders
    private func productImageView(height: CGFloat, width: CGFloat? = nil, imageUrl: String? = nil) -> some View {
        let urlString = imageUrl ?? primaryImageUrl
        let imageURL = URL(string: urlString ?? "")
        
        let imageView = LoadedImage(
            url: imageURL,
            placeholder: AnyView(placeholderView(systemImage: "photo", color: adaptiveColors.textSecondary)),
            errorView: AnyView(placeholderView(systemImage: "exclamationmark.triangle", color: adaptiveColors.error))
        )
        .aspectRatio(contentMode: .fill)
        .frame(width: width, height: height)
        .clipped()
        
        // Wrap with background color if specified
        if let backgroundColor = imageBackgroundColor {
            return AnyView(
                ZStack {
                    Rectangle()
                        .fill(backgroundColor)
                        .frame(width: width, height: height)
                    
                    imageView
                }
                .cornerRadius(VioBorderRadius.medium)
            )
        } else {
            return AnyView(imageView.cornerRadius(VioBorderRadius.medium))
        }
    }
    
    /// Placeholder view for loading/error states
    private func placeholderView(systemImage: String, color: Color) -> some View {
        Rectangle()
            .fill(adaptiveColors.background)
            .overlay(
                VStack(spacing: VioSpacing.xs) {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundColor(color)
                    
                    if systemImage == "exclamationmark.triangle" {
                        Text(VLocalizedString(VioTranslationKey.noImageAvailable.rawValue))
                            .font(VioTypography.caption1)
                            .foregroundColor(color)
                            .multilineTextAlignment(.center)
                    }
                }
            )
    }
    
    /// Calculate discount percentage from compareAt price
    private func calculateDiscountPercentage() -> Int? {
        // Use prices with taxes for discount calculation
        let currentPrice = product.price.amount_incl_taxes ?? product.price.amount
        let originalPrice = product.price.compare_at_incl_taxes ?? product.price.compare_at
        
        guard let compareAt = originalPrice, compareAt > currentPrice else {
            return nil
        }
        
        let discount = ((compareAt - currentPrice) / compareAt) * 100
        return Int(discount.rounded())
    }
    
    /// Discount badge for product cards
    private func discountBadge(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(adaptiveColors.textOnPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(adaptiveColors.primary)
            )
            .padding(8)
    }
    
    // MARK: - Reusable Components
    
    private var priceView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(product.price.displayAmount)
                .font(
                    variant == .hero ? VioTypography.title3 : 
                    variant == .minimal ? .system(size: 11, weight: .semibold) :
                    variant == .list ? .system(size: 14, weight: .semibold) :
                    variant == .grid ? .system(size: 14, weight: .semibold) :
                    VioTypography.body
                )
                .fontWeight(.semibold)
                .foregroundColor(adaptiveColors.priceColor)
                .onAppear {
                    print("💰 [VProductCard] Showing product: \(product.title)")
                    print("💰 [VProductCard] Price amount: \(product.price.amount)")
                    print("💰 [VProductCard] Price with taxes: \(product.price.amount_incl_taxes ?? 0.0)")
                    print("💰 [VProductCard] Display amount: \(product.price.displayAmount)")
                    print("💰 [VProductCard] Currency: \(product.price.currency_code)")
                }
            
            if let compareAtAmount = product.price.displayCompareAtAmount {
                Text(compareAtAmount)
                    .font(
                        variant == .minimal ? .system(size: 10, weight: .regular) :
                        variant == .list ? .system(size: 11, weight: .regular) :
                        variant == .grid ? .system(size: 12, weight: .regular) :
                        VioTypography.caption1
                    )
                    .foregroundColor(adaptiveColors.textSecondary)
                    .strikethrough()
            } else {
                // Spacer to maintain consistent height when compare_at is not present
                Text("")
                    .font(
                        variant == .minimal ? .system(size: 10, weight: .regular) :
                        variant == .list ? .system(size: 11, weight: .regular) :
                        variant == .grid ? .system(size: 12, weight: .regular) :
                        VioTypography.caption1
                    )
                    .opacity(0)
            }
        }
        .frame(minHeight: variant == .minimal ? 20 : variant == .list ? 24 : variant == .grid ? 28 : 32)  // Fixed minimum height for consistent card sizes
    }
    
    private var addToCartButton: some View {
        Group {
            if variant == .minimal {
                // No button in minimal variant
                EmptyView()
            } else if isInStock {
                VButton(
                    title: showCheckmark ? (variant == .list ? "✓" : variant == .grid ? "" : VLocalizedString(VioTranslationKey.success.rawValue)) : (variant == .list ? VLocalizedString(VioTranslationKey.addToCart.rawValue) : variant == .grid ? "" : VLocalizedString(VioTranslationKey.addToCart.rawValue)),
                    style: .primary,
                    size: variant == .list ? .small : variant == .grid ? .small : .medium,
                    isLoading: isAddingToCart,
                    icon: variant == .grid ? (showCheckmark ? "checkmark" : "plus") : showCheckmark && variant != .list ? "checkmark" : nil
                ) {
                    animateAddToCart()
                }
                .disabled(isAddingToCart)
                .scaleEffect(buttonScale)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: buttonScale)
            } else {
                Text(VLocalizedString(VioTranslationKey.outOfStock.rawValue))
                    .font(VioTypography.caption1)
                    .foregroundColor(adaptiveColors.error)
                    .padding(.horizontal, VioSpacing.sm)
                    .padding(.vertical, VioSpacing.xs)
                    .background(adaptiveColors.error.opacity(0.1))
                    .cornerRadius(VioBorderRadius.small)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isInStock: Bool {
        (product.quantity ?? 0) > 0
    }
    
    // MARK: - Animation Functions
    
    private func animateAddToCart() {
        // Start loading animation
        withAnimation(.easeInOut(duration: 0.1)) {
            buttonScale = 0.9
            isAddingToCart = true
        }
        
        // Scale back and show checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                buttonScale = 1.0
                showCheckmark = true
            }
        }
        
        // Reset after showing checkmark
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showCheckmark = false
                isAddingToCart = false
            }
        }
        
        // Track product added to cart
        AnalyticsManager.shared.trackProductAddedToCart(
            productId: String(product.id),
            productName: product.title,
            quantity: 1,
            productPrice: Double(product.price.amount),
            productCurrency: product.price.currency_code,
            source: "product_card"
        )
        
        // Call the actual add to cart function
        onAddToCart?()
    }
    
    /// Handle tap on product card
    private func handleTap() {
        // Track product viewed (when opening product detail)
        if showProductDetail {
            AnalyticsManager.shared.trackProductViewed(
                productId: String(product.id),
                productName: product.title,
                productPrice: Double(product.price.amount),
                productCurrency: product.price.currency_code,
                source: "product_store"
            )
            showingProductDetail = true
        } else {
            onTap?()
        }
    }
    
    /// Images sorted by 'order' field, prioritizing 0 and 1
    private var sortedImages: [ProductImage] {
        let images = product.images
        
        // If no images, return empty array
        guard !images.isEmpty else { return [] }
        
        // Sort by 'order' field, with 0 and 1 at the beginning
        return images.sorted { first, second in
            // Prioritize order 0 and 1
            let firstPriority = (first.order == 0 || first.order == 1) ? first.order : Int.max
            let secondPriority = (second.order == 0 || second.order == 1) ? second.order : Int.max
            
            if firstPriority != secondPriority {
                return firstPriority < secondPriority
            }
            
            // If both have the same priority, sort by normal order
            return first.order < second.order
        }
    }
    
    /// URL of the primary image (first in order)
    private var primaryImageUrl: String? {
        sortedImages.first?.url
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Grid Variant") {
    VStack(spacing: VioSpacing.lg) {
        VProductCard(
            product: MockDataProvider.shared.sampleProducts[0],
            variant: .grid,
            onTap: { print("Product tapped") },
            onAddToCart: { print("Add to cart tapped") }
        )
    }
    .padding()
    .background(Color.clear)
}

#Preview("List Variant") {
    VStack(spacing: VioSpacing.md) {
        ForEach(MockDataProvider.shared.sampleProducts.prefix(3)) { product in
            VProductCard(
                product: product,
                variant: .list,
                onTap: { print("Product \(product.title) tapped") },
                onAddToCart: { print("Add \(product.title) to cart") }
            )
        }
    }
    .padding()
    .background(Color.clear)
}

#Preview("Hero Variant") {
    VProductCard(
        product: MockDataProvider.shared.sampleProducts[0],
        variant: .hero,
        showDescription: true,
        onTap: { print("Hero product tapped") },
        onAddToCart: { print("Hero add to cart") }
    )
    .padding()
    .background(Color.clear)
}

#Preview("Minimal Variant") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: VioSpacing.sm) {
            ForEach(MockDataProvider.shared.sampleProducts) { product in
                VProductCard(
                    product: product,
                    variant: .minimal,
                    onTap: { print("Minimal product \(product.title) tapped") }
                )
            }
        }
        .padding(.horizontal)
    }
    .background(Color.clear)
}

#Preview("All Variants Comparison") {
    ScrollView {
        VStack(spacing: VioSpacing.xl) {
            VStack(alignment: .leading) {
                Text("Grid Variant")
                    .font(VioTypography.headline)
                    .padding(.horizontal)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VioSpacing.md) {
                    ForEach(MockDataProvider.shared.sampleProducts.prefix(2)) { product in
                        VProductCard(product: product, variant: .grid)
                    }
                }
                .padding(.horizontal)
            }
            
            VStack(alignment: .leading) {
                Text("List Variant")
                    .font(VioTypography.headline)
                    .padding(.horizontal)
                
                VStack(spacing: VioSpacing.sm) {
                    ForEach(MockDataProvider.shared.sampleProducts.prefix(2)) { product in
                        VProductCard(product: product, variant: .list)
                    }
                }
                .padding(.horizontal)
            }
            
            VStack(alignment: .leading) {
                Text("Hero Variant")
                    .font(VioTypography.headline)
                    .padding(.horizontal)
                
                VProductCard(
                    product: MockDataProvider.shared.sampleProducts[0],
                    variant: .hero,
                    showDescription: true
                )
                .padding(.horizontal)
            }
            
            VStack(alignment: .leading) {
                Text("Minimal Variant")
                    .font(VioTypography.headline)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VioSpacing.sm) {
                        ForEach(MockDataProvider.shared.sampleProducts) { product in
                            VProductCard(product: product, variant: .minimal)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
    }
    .background(Color.clear)
}
#endif
