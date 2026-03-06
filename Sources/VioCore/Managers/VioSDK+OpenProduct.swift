import Foundation
#if canImport(UIKit)
import UIKit

/// Protocol for fetching products by ID. VioUI registers an implementation that uses ProductService
/// (same path as carousel). When set, openProduct uses it; otherwise falls back to CommerceProductFetcher.
public protocol VioSDKProductFetcher: AnyObject {
    func fetchProduct(id: String, currency: String, country: String) async -> Product?
}

/// Extensión pública para abrir un producto desde una push notification.
public enum VioSDK {

    /// Strong reference so the fetcher is not deallocated after registration.
    private static var _productFetcher: VioSDKProductFetcher?

    /// Product fetcher for openProduct. When set (by VioUI), uses ProductService (same as carousel).
    public static var productFetcher: VioSDKProductFetcher? {
        get { _productFetcher }
        set { _productFetcher = newValue }
    }

    /// Register a product fetcher. Call from VioUI at init to use ProductService for openProduct.
    public static func registerProductFetcher(_ fetcher: VioSDKProductFetcher) {
        _productFetcher = fetcher
    }

    @MainActor
    public static func openProduct(id: String) async {
        print("🔵 [VioSDK] openProduct(\(id)) llamado")
        print("🔵 [VioSDK] shouldUseSDK=\(VioConfiguration.shared.shouldUseSDK) isCampaignActive=\(CampaignManager.shared.isCampaignActive)")

        guard VioConfiguration.shared.shouldUseSDK else {
            print("❌ [VioSDK] SDK no configurado — saliendo")
            return
        }

        let currency = VioConfiguration.shared.marketConfiguration.currencyCode
        let country = VioConfiguration.shared.marketConfiguration.countryCode

        let product: Product?
        if let fetcher = _productFetcher {
            print("🔵 [VioSDK] Fetching producto \(id) via ProductFetcher (ProductService)")
            product = await fetcher.fetchProduct(id: id, currency: currency, country: country)
        } else {
            print("🔵 [VioSDK] Fetching producto \(id) desde Commerce (fallback)")
            product = await CommerceProductFetcher.fetch(id: id)
        }

        guard let product = product else {
            print("❌ [VioSDK] No se pudo obtener producto \(id)")
            return
        }

        print("✅ [VioSDK] Producto: \(product.title) — emitiendo overlay")
        NotificationCenter.default.post(
            name: .vioOpenProductOverlay,
            object: nil,
            userInfo: ["product": product]
        )
        print("📤 [VioSDK] vioOpenProductOverlay emitido")
    }
}

public extension Notification.Name {
    static let vioOpenProductOverlay = Notification.Name("live.vio.openProductOverlay")
}

private enum CommerceProductFetcher {

    struct SlimProduct: Codable {
        let id: Int
        let title: String
        let images: [SlimImage]?
        let price: SlimPrice?
        let variants: [SlimVariant]?
        struct SlimImage: Codable { let url: String?; let order: Int? }
        struct SlimPrice: Codable {
            let amount: Float?
            let amount_incl_taxes: Float?
            let currency_code: String?
        }
        struct SlimVariant: Codable {
            let id: Int?
            let title: String?
            let quantity: Int?
            let price: SlimPrice?
        }
    }

    static func fetch(id: String) async -> Product? {
        let baseURL = "https://graph-ql-dev.vio.live/graphql"
        let apiKey = VioConfiguration.shared.dynamicCommerceConfig?.apiKey ?? ""

        print("🔵 [Commerce] Fetching id=\(id) apiKey=\(apiKey.prefix(8))...")
        guard !apiKey.isEmpty, let url = URL(string: baseURL) else {
            print("❌ [Commerce] apiKey vacío o URL inválida")
            return nil
        }

        // Query mínima: sku/description causan 500 en algunos productos; variants sin sku para evitar errores
        let query = "{ Channel { GetProductsByIds(product_ids: [\(id)]) { id title images { url order } price { amount amount_incl_taxes currency_code } variants { id title quantity price { amount amount_incl_taxes currency_code } } } } }"

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["query": query])

        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            print("❌ [Commerce] Network error")
            return nil
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let raw = String(data: data, encoding: .utf8) ?? ""
        print("🔵 [Commerce] HTTP \(status) raw: \(raw.prefix(400))")

        struct GQLResponse: Codable {
            struct GData: Codable {
                struct Channel: Codable { let GetProductsByIds: [SlimProduct]? }
                let Channel: Channel?
            }
            let data: GData?
        }

        guard let slim = (try? JSONDecoder().decode(GQLResponse.self, from: data))?.data?.Channel?.GetProductsByIds?.first else {
            let raw = String(data: data, encoding: .utf8) ?? ""
            print("❌ [Commerce] Decode falló. Raw: \(raw.prefix(300))")
            return nil
        }

        print("✅ [Commerce] Producto obtenido: \(slim.title)")

        // Convertir a Product para VProductDetailOverlay
        let images = (slim.images ?? []).compactMap { img -> ProductImage? in
            guard let urlStr = img.url else { return nil }
            return ProductImage(id: String(img.order ?? 0), url: urlStr, order: img.order ?? 0)
        }
        let price = Price(
            amount: slim.price?.amount ?? 0,
            currency_code: slim.price?.currency_code ?? "NOK",
            amount_incl_taxes: slim.price?.amount_incl_taxes
        )
        let variants: [Variant] = (slim.variants ?? []).map { v in
            let vPrice = Price(
                amount: v.price?.amount ?? price.amount,
                currency_code: v.price?.currency_code ?? price.currency_code,
                amount_incl_taxes: v.price?.amount_incl_taxes
            )
            return Variant(id: String(v.id ?? 0), price: vPrice, quantity: v.quantity, sku: "", title: v.title ?? "")
        }

        return Product(
            id: slim.id,
            title: slim.title,
            brand: nil,
            description: nil,
            tags: nil,
            sku: "",
            quantity: nil,
            price: price,
            variants: variants,
            barcode: nil,
            options: nil,
            categories: nil,
            images: images,
            product_shipping: nil,
            supplier: "",
            supplier_id: nil,
            imported_product: nil,
            referral_fee: nil,
            options_enabled: false,
            digital: false,
            origin: "",
            return: nil
        )
    }
}
#endif
