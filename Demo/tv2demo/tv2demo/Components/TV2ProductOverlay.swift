import SwiftUI
import VioCore
import VioUI
import VioCastingUI

/// Componente para mostrar un producto individual
/// Estilo basado en las cards del SDK de Vio
/// Los productos se fetchean desde la API de Vio usando el ID del WebSocket
struct TV2ProductOverlay: View {
    let productEvent: ProductEventData  // Datos del WebSocket (incluye ID y fallback)
    let isChatExpanded: Bool
    let sdk: SdkClient
    let currency: String
    let country: String
    let onAddToCart: (ProductDto?) -> Void  // Pasa el producto real de la API si está disponible
    let onDismiss: () -> Void
    
    @StateObject private var viewModel: ProductFetchViewModel
    @State private var dragOffset: CGFloat = 0
    @State private var showCheckmark = false
    @State private var showProductDetail = false
    @EnvironmentObject private var cartManager: CartManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    init(
        productEvent: ProductEventData,
        isChatExpanded: Bool,
        sdk: SdkClient,
        currency: String,
        country: String,
        onAddToCart: @escaping (ProductDto?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.productEvent = productEvent
        self.isChatExpanded = isChatExpanded
        self.sdk = sdk
        self.currency = currency
        self.country = country
        self.onAddToCart = onAddToCart
        self.onDismiss = onDismiss
        
        // Inicializar el ViewModel
        let vm = ProductFetchViewModel(sdk: sdk, currency: currency, country: country)
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    // Ajustar bottom padding basado en si el chat está expandido
    private var bottomPadding: CGFloat {
        if isLandscape {
            return isChatExpanded ? 250 : 156 // En landscape, espacio para el chat con 2 mensajes (140 + 16)
        } else {
            return isChatExpanded ? 250 : 80 // Más espacio cuando el chat está expandido
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLandscape {
                // Horizontal: lado derecho, ancho suficiente para contenido
                Spacer()
                HStack(spacing: 0) {
                    Spacer()
                    productCard
                        .frame(width: 280)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                        .offset(x: dragOffset)
                        .gesture(dragGesture)
                }
            } else {
                // Vertical: sobre el chat
                Spacer()
                productCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, bottomPadding)
                    .offset(y: dragOffset)
                    .gesture(dragGesture)
            }
        }
        .task(id: productEvent.productId) {
            // Fetch del producto cuando aparece el componente o cambia el productId
            await viewModel.fetchProduct(productId: productEvent.productId)
        }
        .sheet(isPresented: $showProductDetail) {
            if let apiProduct = viewModel.product {
                // Convertir ProductDto a Product para el overlay
                VProductDetailOverlay(
                    product: convertDtoToProduct(apiProduct),
                    onDismiss: {
                        showProductDetail = false
                    },
                    onAddToCart: { product in
                        // VioProductDetailOverlay ya agrega al cart internamente
                        // Solo cerramos el modal y mostramos feedback
                        showProductDetail = false
                        showCheckmark = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCheckmark = false
                        }
                    }
                )
                .environmentObject(cartManager)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Nombre del producto (API > WebSocket fallback)
    private var displayName: String {
        if let apiProduct = viewModel.product {
            return apiProduct.title
        }
        return productEvent.name
    }
    
    /// Descripción del producto (API > WebSocket fallback)
    private var displayDescription: String {
        let rawDescription: String
        if let apiProduct = viewModel.product {
            rawDescription = apiProduct.description ?? ""
        } else {
            rawDescription = productEvent.description
        }
        // Limpiar HTML tags
        return cleanHTMLString(rawDescription)
    }
    
    /// Limpia tags HTML de un string
    private func cleanHTMLString(_ html: String) -> String {
        // Remover tags HTML
        var cleaned = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decodificar entidades HTML comunes
        cleaned = cleaned.replacingOccurrences(of: "&nbsp;", with: " ")
        cleaned = cleaned.replacingOccurrences(of: "&amp;", with: "&")
        cleaned = cleaned.replacingOccurrences(of: "&lt;", with: "<")
        cleaned = cleaned.replacingOccurrences(of: "&gt;", with: ">")
        cleaned = cleaned.replacingOccurrences(of: "&quot;", with: "\"")
        cleaned = cleaned.replacingOccurrences(of: "&#39;", with: "'")
        // Limpiar espacios múltiples y saltos de línea
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Precio formateado del producto (API > WebSocket fallback)
    private var displayPrice: String {
        if let apiProduct = viewModel.product {
            // Use price with taxes if available, otherwise use base price
            let priceToShow = apiProduct.price.amountInclTaxes ?? apiProduct.price.amount
            return "\(apiProduct.price.currencyCode) \(String(format: "%.2f", priceToShow))"
        }
        return productEvent.price
    }
    
    /// URL de la imagen del producto (API > WebSocket fallback)
    private var displayImageUrl: String {
        if let apiProduct = viewModel.product,
           let firstImage = apiProduct.images.first {
            return firstImage.url
        }
        return productEvent.imageUrl
    }
    
    /// campaignLogo siempre viene del WebSocket
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
    
    // MARK: - Conversion Helper
    
    /// Convierte ProductDto a Product para usar con VioProductDetailOverlay
    private func convertDtoToProduct(_ dto: ProductDto) -> Product {
        // Limpiar HTML de la descripción
        let cleanDescription = dto.description.map { cleanHTMLString($0) }
        
        return Product(
            id: dto.id,
            title: dto.title,
            brand: dto.brand,
            description: cleanDescription,
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
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if isLandscape {
                    if value.translation.width > 0 {
                        dragOffset = value.translation.width
                    }
                } else {
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 100
                if isLandscape {
                    if value.translation.width > threshold {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                } else {
                    if value.translation.height > threshold {
                        onDismiss()
                    } else {
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
                }
            }
    }
    
    private var productCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                // Drag indicator
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 4)
                
                // Loading indicator sutil mientras se carga
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white)
                        Text("Laster produkt…")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 4)
                }
                
                // Sponsor badge arriba a la izquierda
                if let campaignLogo = displayCampaignLogo, !campaignLogo.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sponset av")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            AsyncImage(url: URL(string: campaignLogo)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 80, maxHeight: 24)
                                case .empty:
                                    ProgressView()
                                        .scaleEffect(0.5)
                                        .frame(width: 80, height: 24)
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
                
                // Producto con imagen pequeña a la izquierda
                HStack(alignment: .top, spacing: 12) {
                    // Imagen del producto pequeña
                    ZStack(alignment: .topTrailing) {
                        AsyncImage(url: URL(string: displayImageUrl)) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 90, height: 90)
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
                        
                        // Tag de descuento diagonal (calculado dinámicamente)
                        if shouldShowDiscountBadge, let discount = discountPercentage {
                            Text("-\(discount)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Color(hex: "E93CAC")
                                )
                                .rotationEffect(.degrees(-10))
                                .offset(x: 8, y: -8)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                    }
                    
                    // Información del producto a la derecha
                    VStack(alignment: .leading, spacing: 6) {
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
                        
                        // Precio
                        Text(displayPrice)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(TV2Theme.Colors.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Botón para ver detalles (NO agrega directamente)
                Button(action: {
                    // Siempre abrir el product detail modal
                    if viewModel.product != nil {
                        showProductDetail = true
                    }
                    // Si el producto aún no ha cargado, no hace nada (espera a que cargue)
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
                            .fill(showCheckmark ? Color.green : (viewModel.product != nil ? Color(hex: "2C0D65") : Color.gray))
                    )
                }
                .disabled(showCheckmark || viewModel.product == nil)
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
            .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 8)
        }
    }
}

/// Componente para mostrar dos productos lado a lado
/// Similar a VioProductSlider pero más compacto
struct TV2TwoProductsOverlay: View {
    let product1: ProductEventData
    let product2: ProductEventData
    let onAddToCart: () -> Void
    let onDismiss: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var addedProducts: Set<String> = []
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            productsCard
                .padding(.horizontal, 16)
                .padding(.bottom, isLandscape ? 16 : 80)
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
        }
    }
    
    private var productsCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                // Drag indicator
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 32, height: 4)
                
                // Sponsor logo arriba a la izquierda
                if let campaignLogo = product1.campaignLogo, !campaignLogo.isEmpty {
                    HStack {
                        AsyncImage(url: URL(string: campaignLogo)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 80, maxHeight: 30)
                            case .empty:
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 80, height: 30)
                            case .failure:
                                EmptyView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                }
                
                // Header
            HStack {
                Text("🛍️ ANBEFALTE PRODUKTER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "5B5FCF"))
                Spacer()
            }
            
            // Productos en grid
            if isLandscape {
                HStack(spacing: 12) {
                    productMiniCard(product1)
                    productMiniCard(product2)
                }
            } else {
                VStack(spacing: 12) {
                    productMiniCard(product1)
                    productMiniCard(product2)
                }
            }
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
            .shadow(color: .black.opacity(0.6), radius: 20, x: 0, y: 8)
            
            // Sponsor badge debajo del contenido principal
            if let campaignLogo = product1.campaignLogo, !campaignLogo.isEmpty {
                HStack {
                    Spacer()
                    TV2SponsorBadge(logoUrl: campaignLogo)
                        .padding(.top, 8)
                        .padding(.trailing, 12)
                }
            }
        }
    }
    
    private func productMiniCard(_ product: ProductEventData) -> some View {
        HStack(spacing: 12) {
            // Imagen
            AsyncImage(url: URL(string: product.imageUrl)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 80, height: 80)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipped()
                        .cornerRadius(8)
                case .failure:
                    Color.gray.opacity(0.3)
                        .frame(width: 80, height: 80)
                        .cornerRadius(8)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.5))
                        )
                @unknown default:
                    EmptyView()
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(product.price)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(TV2Theme.Colors.primary)
                
                Spacer()
                
                // Botón compacto
                Button(action: {
                    onAddToCart()
                    addedProducts.insert(product.id)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        addedProducts.remove(product.id)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: addedProducts.contains(product.id) ? "checkmark.circle.fill" : "cart.fill")
                            .font(.system(size: 12))
                        Text(addedProducts.contains(product.id) ? "Lagt til" : "Legg til")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(addedProducts.contains(product.id) ? Color.green : Color(hex: "5B5FCF"))
                    )
                }
                .disabled(addedProducts.contains(product.id))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - Previews

#Preview("Single Product") {
    let baseURL = URL(string: "https://api-ecom.vio.live/graphql")!
    let sdk = SdkClient(baseUrl: baseURL, apiKey: "DEMO_KEY")
    
    ZStack {
        Color.black.ignoresSafeArea()
        
        TV2ProductOverlay(
            productEvent: ProductEventData(
                id: "prod_123",
                productId: "408841",  // ID numérico real de Vio
                name: "iPhone 15 Pro Max (WebSocket Fallback)",
                description: "El último modelo con titanio y cámara de 48MP",
                price: "$1,199",
                currency: "USD",
                imageUrl: "https://images.unsplash.com/photo-1592286927505-b7e00a46f74f",
                campaignLogo: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Adidas_logo.png/800px-Adidas_logo.png"
            ),
            isChatExpanded: false,
            sdk: sdk,
            currency: "USD",
            country: "US",
            onAddToCart: { product in
                if let p = product {
                    print("Agregado al carrito (API): \(p.title)")
                } else {
                    print("Agregado al carrito (WebSocket fallback)")
                }
            },
            onDismiss: {
                print("Cerrado")
            }
        )
    }
}

#Preview("Two Products") {
    ZStack {
        Color.black.ignoresSafeArea()
        
        TV2TwoProductsOverlay(
            product1: ProductEventData(
                id: "prod_1",
                productId: "408841",
                name: "iPhone 15 Pro",
                description: "Titanio azul",
                price: "$999",
                currency: "USD",
                imageUrl: "https://images.unsplash.com/photo-1592286927505-b7e00a46f74f",
                campaignLogo: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Adidas_logo.png/800px-Adidas_logo.png"
            ),
            product2: ProductEventData(
                id: "prod_2",
                productId: "408842",
                name: "AirPods Pro",
                description: "Con USB-C",
                price: "$249",
                currency: "USD",
                imageUrl: "https://images.unsplash.com/photo-1572569511254-d8f925fe2cbb",
                campaignLogo: "https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Adidas_logo.png/800px-Adidas_logo.png"
            ),
            onAddToCart: {
                print("Agregado")
            },
            onDismiss: {
                print("Cerrado")
            }
        )
    }
}

