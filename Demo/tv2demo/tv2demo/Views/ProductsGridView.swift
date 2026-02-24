import SwiftUI
import VioUI
import VioCore

/// Products Grid View
/// Vista con grid de productos similar a VioDemoApp
struct ProductsGridView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var cartManager: CartManager
    
    @State private var products: [Product] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let title: String
    
    init(title: String = "Ukens tilbud") {
        self.title = title
    }
    
    // Grid layout
    private let columns = [
        GridItem(.flexible(), spacing: TV2Theme.Spacing.md),
        GridItem(.flexible(), spacing: TV2Theme.Spacing.md)
    ]
    
    var body: some View {
        ZStack {
            // Background
            TV2Theme.Colors.background
                .ignoresSafeArea()
            
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else if products.isEmpty {
                emptyView
            } else {
                productsGridContent
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: TV2Theme.Spacing.md) {
                    Button(action: {}) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(TV2Theme.Colors.textPrimary)
                    }
                    
                    Button(action: {}) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(TV2Theme.Colors.primary)
                    }
                }
            }
        }
        .task {
            await loadProducts()
        }
    }
    
    // MARK: - Products Grid Content
    private var productsGridContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: TV2Theme.Spacing.md) {
                ForEach(products) { product in
                    VioProductCard(
                        product: product,
                        onAddToCart: {
                            Task {
                                await addToCart(product: product)
                            }
                        }
                    )
                    .environmentObject(cartManager)
                }
            }
            .padding(.horizontal, TV2Theme.Spacing.md)
            .padding(.top, TV2Theme.Spacing.md)
            .padding(.bottom, TV2Theme.Spacing.xl)
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: TV2Theme.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: TV2Theme.Colors.primary))
            
            Text("Laster produkter...")
                .font(TV2Theme.Typography.body)
                .foregroundColor(TV2Theme.Colors.textSecondary)
        }
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: TV2Theme.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Noe gikk galt")
                .font(TV2Theme.Typography.title)
                .foregroundColor(TV2Theme.Colors.textPrimary)
            
            Text(message)
                .font(TV2Theme.Typography.body)
                .foregroundColor(TV2Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TV2Theme.Spacing.xl)
            
            Button(action: {
                Task {
                    await loadProducts()
                }
            }) {
                Text("Prøv igjen")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, TV2Theme.Spacing.xl)
                    .padding(.vertical, TV2Theme.Spacing.md)
                    .background(
                        Capsule()
                            .fill(TV2Theme.Colors.primary)
                    )
            }
        }
        .padding(TV2Theme.Spacing.xl)
    }
    
    // MARK: - Empty View
    private var emptyView: some View {
        VStack(spacing: TV2Theme.Spacing.lg) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(TV2Theme.Colors.textSecondary)
            
            Text("Ingen produkter")
                .font(TV2Theme.Typography.title)
                .foregroundColor(TV2Theme.Colors.textPrimary)
            
            Text("Det er ingen tilbud tilgjengelig for øyeblikket")
                .font(TV2Theme.Typography.body)
                .foregroundColor(TV2Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TV2Theme.Spacing.xl)
        }
        .padding(TV2Theme.Spacing.xl)
    }
    
    // MARK: - Actions
    private func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        print("🛍️ [ProductsGridView] Loading products...")
        print("   Currency: \(cartManager.currency)")
        print("   Country: \(cartManager.country)")
        
        do {
            // Create SDK client
            let config = VioConfiguration.shared
            let baseURL = URL(string: config.environment.graphQLURL)!
            let apiKey = config.apiKey.isEmpty ? "DEMO_KEY" : config.apiKey
            let sdk = SdkClient(baseUrl: baseURL, apiKey: apiKey)
            
            // Fetch products
            let dtoProducts = try await sdk.channel.product.get(
                currency: cartManager.currency,
                imageSize: "large",
                barcodeList: nil,
                categoryIds: nil,
                productIds: nil,
                skuList: nil,
                useCache: true,
                shippingCountryCode: cartManager.country
            )
            
            products = dtoProducts.map { $0.toDomainProduct() }
            
            print("✅ [ProductsGridView] Loaded \(products.count) products")
            
        } catch let error as SdkException {
            errorMessage = error.description
            print("❌ [ProductsGridView] Failed to load products: \(error.description)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [ProductsGridView] Failed to load products: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func addToCart(product: Product) async {
        print("🛒 [ProductsGridView] Adding to cart: \(product.title)")
        
        await cartManager.addProduct(product, quantity: 1)
    }
}

#Preview {
    NavigationView {
        ProductsGridView()
            .environmentObject(CartManager())
    }
    .preferredColorScheme(.dark)
}

