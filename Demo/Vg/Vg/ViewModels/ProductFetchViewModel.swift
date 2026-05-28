import Foundation
import SwiftUI
import Combine
import VioCore
import VioUI

/// ViewModel para fetch de productos individuales desde la API de Vio
/// Usado por los overlays de productos del WebSocket
@MainActor
class ProductFetchViewModel: ObservableObject {
    @Published var product: ProductDto?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let defaultSdk: SdkClient
    private let graphQLBaseURL: URL
    private let currency: String
    private let country: String
    
    init(sdk: SdkClient, currency: String, country: String) {
        self.defaultSdk = sdk
        self.graphQLBaseURL = sdk.baseUrl
        self.currency = currency
        self.country = country
    }
    
    /// Fetch un producto por su productId (ID numérico de Vio).
    /// - Parameter apiKey: Si viene del artículo Vev (`&apikey=`), se usa para GraphQL en lugar de la key del app.
    func fetchProduct(productId: String, apiKey: String? = nil) async {
        guard !productId.isEmpty else {
            print("⚠️ [ProductFetch] productId vacío, no se puede fetch")
            return
        }
        
        isLoading = true
        errorMessage = nil
        product = nil
        
        let sdk = sdkForFetch(apiKey: apiKey)
        print("🔍 [ProductFetch] Fetching producto con productId: \(productId)")
        print("   Currency: \(currency)")
        print("   Country: \(country)")
        print("   GraphQL apiKey: \(maskedApiKey(apiKey ?? VioConfiguration.shared.apiKey))")
        
        do {
            // Convertir String productId a Int
            guard let productIdInt = Int(productId) else {
                self.errorMessage = "productId inválido: \(productId)"
                print("❌ [ProductFetch] productId no es un número válido: \(productId)")
                isLoading = false
                return
            }
            
            // Usar getByIds que es el método optimizado para buscar por IDs
            let products = try await sdk.product.getByIds(
                productIds: [productIdInt],
                currency: currency,
                imageSize: "large",
                useCache: false,
                shippingCountryCode: country
            )
            
            if let fetchedProduct = products.first {
                self.product = fetchedProduct
                print("✅ [ProductFetch] Producto obtenido: \(fetchedProduct.title)")
                print("   Precio: \(formatPrice(fetchedProduct.price))")
                if let imageUrl = fetchedProduct.images.first?.url {
                    print("   Imagen: \(imageUrl)")
                }
            } else {
                self.errorMessage = "Producto no encontrado"
                print("❌ [ProductFetch] Producto con productId \(productId) no encontrado en la respuesta")
            }
            
            isLoading = false
            
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            print("❌ [ProductFetch] Error fetching producto: \(error)")
        }
    }
    
    // MARK: - Helpers

    private func sdkForFetch(apiKey: String?) -> SdkClient {
        if let apiKey, !apiKey.isEmpty {
            return SdkClient(baseUrl: graphQLBaseURL, apiKey: apiKey)
        }
        return defaultSdk
    }

    private func maskedApiKey(_ key: String) -> String {
        guard !key.isEmpty else { return "(empty)" }
        if key.count <= 4 { return "****" }
        return String(repeating: "*", count: max(0, key.count - 4)) + key.suffix(4)
    }
    
    /// Formatea el precio para display
    private func formatPrice(_ price: PriceDto) -> String {
        let amount = price.amountInclTaxes ?? price.amount
        return "\(price.currencyCode) \(String(format: "%.2f", amount))"
    }
}

