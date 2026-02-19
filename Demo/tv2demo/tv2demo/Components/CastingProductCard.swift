import SwiftUI
import VioCore
import VioUI

/// Versión compacta de producto específica para la vista de casting
struct CastingProductCard: View {
    let productEvent: ProductEventData
    let sdk: SdkClient
    let currency: String
    let country: String
    let onAddToCart: (ProductDto) -> Void
    let onDismiss: () -> Void
    
    @State private var product: ProductDto?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 12) {
            if isLoading {
                loadingView
            } else if let product = product {
                productContent(product)
            } else {
                // Si no hay producto y ya terminó de cargar, no mostrar nada
                EmptyView()
            }
        }
        .padding(16)
        .frame(width: 420) // ANCHO FIJO
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .background(.ultraThinMaterial)
        )
        .cornerRadius(12)
        .onAppear {
            fetchProduct()
        }
        .opacity((isLoading || product != nil) ? 1 : 0) // Ocultar si no hay producto
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        HStack {
            ProgressView()
                .tint(.white)
            Text("Cargando producto...")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(height: 80)
    }
    
    // MARK: - Product Content
    
    private func productContent(_ product: ProductDto) -> some View {
        HStack(spacing: 14) {
            // Product image
            if let imageUrl = product.images.first?.url {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(8)
                    case .empty:
                        ProgressView()
                            .tint(.white)
                            .frame(width: 80, height: 80)
                    case .failure:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            } else {
                placeholderImage
            }
            
            // Product info
            VStack(alignment: .leading, spacing: 6) {
                Text(product.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text("\(Int(product.price.amount)) \(product.price.currencyCode)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(TV2Theme.Colors.primary)
                
                Spacer()
            }
            
            Spacer()
            
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(14)
            }
        }
        .frame(height: 80)
    }
    
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.1))
            .frame(width: 80, height: 80)
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.white.opacity(0.3))
            )
    }
    
    // MARK: - Fetch Product
    
    private func fetchProduct() {
        Task {
            do {
                guard let productIdInt = Int(productEvent.productId) else {
                    print("⚠️ [CastingProductCard] Invalid productId: \(productEvent.productId)")
                    await MainActor.run {
                        self.isLoading = false
                        // Auto-dismiss después de un breve delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.onDismiss()
                        }
                    }
                    return
                }
                
                
                let products = try await sdk.product.getByIds(
                    productIds: [productIdInt],
                    currency: currency,
                    imageSize: "large",
                    useCache: false,
                    shippingCountryCode: country
                )
                
                await MainActor.run {
                    if let fetchedProduct = products.first {
                        self.product = fetchedProduct
                        print("✅ [CastingProductCard] Product fetched: \(fetchedProduct.title)")
                    } else {
                        print("⚠️ [CastingProductCard] Product not found in API: \(productEvent.productId)")
                        // Auto-dismiss después de un breve delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.onDismiss()
                        }
                    }
                    self.isLoading = false
                }
            } catch {
                print("⚠️ [CastingProductCard] Product not available (404 expected in demo): \(error)")
                await MainActor.run {
                    self.isLoading = false
                    // Auto-dismiss después de un breve delay si el producto no existe
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        
        CastingProductCard(
            productEvent: ProductEventData(
                id: "1",
                productId: "123",
                name: "Demo Product",
                description: "A demo product for preview",
                price: "299",
                currency: "NOK",
                imageUrl: "",
                campaignLogo: nil
            ),
            sdk: SdkClient(
                baseUrl: URL(string: "https://api.reachu.io/graphql")!,
                apiKey: "demo"
            ),
            currency: "NOK",
            country: "NO",
            onAddToCart: { _ in },
            onDismiss: {}
        )
        .padding()
    }
}

