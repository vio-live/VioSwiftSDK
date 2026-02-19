import SwiftUI
import VioCore
import VioUI

/// Wrapper de TV2ProductOverlay.productCard con ProductFetchViewModel propio
/// Carga datos desde Vio API y los muestra
struct CastingProductCardView: View {
    let productEvent: ProductEventData
    let sdk: SdkClient
    let currency: String
    let country: String
    let onAddToCart: (ProductDto?) -> Void
    let onDismiss: () -> Void
    
    @StateObject private var viewModel: ProductFetchViewModel
    @State private var showCheckmark = false
    @State private var showProductDetail = false
    @State private var dragOffset: CGFloat = 0
    
    init(
        productEvent: ProductEventData,
        sdk: SdkClient,
        currency: String,
        country: String,
        onAddToCart: @escaping (ProductDto?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.productEvent = productEvent
        self.sdk = sdk
        self.currency = currency
        self.country = country
        self.onAddToCart = onAddToCart
        self.onDismiss = onDismiss
        
        // Crear ProductFetchViewModel NUEVO para este producto
        let vm = ProductFetchViewModel(sdk: sdk, currency: currency, country: country)
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    // MARK: - Computed Properties (COPIADAS de TV2ProductOverlay)
    
    private var displayName: String {
        if let apiProduct = viewModel.product {
            return apiProduct.title
        }
        return productEvent.name
    }
    
    private var displayDescription: String {
        let rawDescription: String
        if let apiProduct = viewModel.product {
            rawDescription = apiProduct.description ?? ""
        } else {
            rawDescription = productEvent.description
        }
        // Clean HTML tags
        return cleanHTMLString(rawDescription)
    }
    
    private func cleanHTMLString(_ html: String) -> String {
        var cleaned = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
        cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var displayPrice: String {
        if let apiProduct = viewModel.product {
            // ALWAYS use price with taxes (what customer actually pays)
            let priceToShow = apiProduct.price.amountInclTaxes ?? apiProduct.price.amount
            return "\(apiProduct.price.currencyCode) \(String(format: "%.2f", priceToShow))"
        }
        return productEvent.price
    }
    
    private var displayImageUrl: String {
        if let apiProduct = viewModel.product,
           let firstImage = apiProduct.images.first {
            return firstImage.url
        }
        return productEvent.imageUrl
    }
    
    private var displayCampaignLogo: String? {
        return productEvent.campaignLogo
    }
    
    private var discountPercentage: Int? {
        guard let apiProduct = viewModel.product else { return nil }
        
        // Use prices with taxes for discount calculation
        let currentPrice = apiProduct.price.amountInclTaxes ?? apiProduct.price.amount
        let originalPrice = apiProduct.price.compareAtInclTaxes ?? apiProduct.price.compareAt
        
        guard let compareAt = originalPrice, compareAt > currentPrice else {
            return nil
        }
        
        let discount = ((compareAt - currentPrice) / compareAt) * 100
        return Int(discount.rounded())
    }
    
    private var shouldShowDiscountBadge: Bool {
        guard VioConfiguration.shared.uiConfiguration.showDiscountBadge else {
            return false
        }
        return discountPercentage != nil && (discountPercentage ?? 0) > 0
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                // Drag indicator
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 4)
                
                // Loading indicator
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                        Text("Cargando producto...")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 4)
                }
                
                // Sponsor badge (from WebSocket)
                if let logoUrl = productEvent.campaignLogo, !logoUrl.isEmpty, let url = URL(string: logoUrl) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sponset av")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 60, maxHeight: 18)
                                case .empty:
                                    ProgressView()
                                        .scaleEffect(0.4)
                                        .tint(.white)
                                        .frame(width: 60, height: 18)
                                case .failure:
                                    EmptyView()
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
                }
                
                // Producto
                HStack(alignment: .top, spacing: 12) {
                    // Imagen
                    ZStack(alignment: .topTrailing) {
                        if viewModel.isLoading {
                            // Skeleton for image
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 90, height: 90)
                                .overlay(
                                    ProgressView()
                                        .tint(.white)
                                )
                        } else {
                            AsyncImage(url: URL(string: displayImageUrl)) { phase in
                                switch phase {
                                case .empty:
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.15))
                                        .frame(width: 90, height: 90)
                                        .overlay(ProgressView().tint(.white))
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 90, height: 90)
                                        .clipped()
                                        .cornerRadius(12)
                                case .failure:
                                    Color.gray.opacity(0.3)
                                        .frame(width: 90, height: 90)
                                        .cornerRadius(12)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .font(.system(size: 24))
                                                .foregroundColor(.white.opacity(0.5))
                                        )
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                        
                        // Tag descuento (calculado dinámicamente)
                        if shouldShowDiscountBadge, let discount = discountPercentage {
                            Text("-\(discount)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "E93CAC"))
                                .rotationEffect(.degrees(-10))
                                .offset(x: 8, y: -8)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }
                    
                    // Info
                    VStack(alignment: .leading, spacing: 6) {
                        if viewModel.isLoading {
                            // Skeleton loading
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 14)
                                    .frame(maxWidth: .infinity)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.2))
                                    .frame(height: 11)
                                    .frame(width: 100)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(TV2Theme.Colors.primary.opacity(0.3))
                                    .frame(height: 16)
                                    .frame(width: 80)
                            }
                        } else {
                            // Actual data
                            Text(displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                            
                            if !displayDescription.isEmpty {
                                Text(displayDescription)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.7))
                                    .lineLimit(2)
                            }
                            
                            Text(displayPrice)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(TV2Theme.Colors.primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Botón
                Button(action: {
                    if viewModel.product != nil {
                        showProductDetail = true
                    } else {
                        onAddToCart(nil)
                        showCheckmark = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCheckmark = false
                        }
                    }
                }) {
                    HStack(spacing: 6) {
                        if showCheckmark {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Lagt til!")
                                .font(.system(size: 13, weight: .semibold))
                        } else {
                            Text("Legg til")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(showCheckmark ? Color.green : Color(hex: "2C0D65"))
                    )
                }
                .disabled(showCheckmark)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.4))
                    .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                    )
            )
        }
        .frame(maxWidth: UIScreen.main.bounds.width - 40) // Margen de 20px a cada lado
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 100 {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .task {
            await viewModel.fetchProduct(productId: productEvent.productId)
        }
        .sheet(isPresented: $showProductDetail) {
            if let apiProduct = viewModel.product {
                VProductDetailOverlay(
                    product: convertDtoToProduct(apiProduct),
                    onDismiss: {
                        showProductDetail = false
                    },
                    onAddToCart: { product in
                        onAddToCart(viewModel.product)
                        showProductDetail = false
                        showCheckmark = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCheckmark = false
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Conversion Helper
    
    private func convertDtoToProduct(_ dto: ProductDto) -> Product {
        return Product(
            id: dto.id,
            title: dto.title,
            brand: dto.brand,
            description: dto.description,
            tags: dto.tags,
            sku: dto.sku,
            quantity: dto.quantity,
            price: Price(
                amount: Float(dto.price.amount),
                currency_code: dto.price.currencyCode,
                amount_incl_taxes: dto.price.amountInclTaxes.map { Float($0) },
                tax_amount: dto.price.taxAmount.map { Float($0) },
                tax_rate: dto.price.taxRate.map { Float($0) },
                compare_at: dto.price.compareAt.map { Float($0) },
                compare_at_incl_taxes: dto.price.compareAtInclTaxes.map { Float($0) }
            ),
            variants: dto.variants.map { v in
                Variant(
                    id: v.id,
                    barcode: v.barcode,
                    price: Price(
                        amount: Float(v.price.amount),
                        currency_code: v.price.currencyCode,
                        amount_incl_taxes: v.price.amountInclTaxes.map { Float($0) },
                        tax_amount: v.price.taxAmount.map { Float($0) },
                        tax_rate: v.price.taxRate.map { Float($0) },
                        compare_at: v.price.compareAt.map { Float($0) },
                        compare_at_incl_taxes: v.price.compareAtInclTaxes.map { Float($0) }
                    ),
                    quantity: v.quantity,
                    sku: v.sku,
                    title: v.title,
                    images: v.images.map { ProductImage(id: $0.id, url: $0.url, width: $0.width, height: $0.height, order: $0.order ?? 0) }
                )
            },
            barcode: dto.barcode,
            options: dto.options.map { Option(id: $0.id, name: $0.name, order: $0.order, values: $0.values) },
            categories: dto.categories?.map { _Category(id: $0.id, name: $0.name) },
            images: dto.images.map { ProductImage(id: $0.id, url: $0.url, width: $0.width, height: $0.height, order: $0.order ?? 0) },
            product_shipping: nil,
            supplier: dto.supplier,
            supplier_id: dto.supplierId,
            imported_product: dto.importedProduct,
            referral_fee: dto.referralFee,
            options_enabled: dto.optionsEnabled,
            digital: dto.digital,
            origin: dto.origin,
            return: nil
        )
    }
}

