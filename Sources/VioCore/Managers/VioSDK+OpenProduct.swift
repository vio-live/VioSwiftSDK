import Foundation
#if canImport(UIKit)
import UIKit

/// Extensión pública para abrir un producto desde una push notification.
public enum VioSDK {

    @MainActor
    public static func openProduct(id: String) async {
        print("🔵 [VioSDK] openProduct(\(id)) llamado")
        print("🔵 [VioSDK] shouldUseSDK=\(VioConfiguration.shared.shouldUseSDK) isCampaignActive=\(CampaignManager.shared.isCampaignActive)")

        guard VioConfiguration.shared.shouldUseSDK else {
            print("❌ [VioSDK] SDK no configurado — saliendo")
            return
        }

        print("🔵 [VioSDK] Fetching producto \(id) desde Commerce...")
        let apiKey = VioConfiguration.shared.dynamicCommerceConfig?.apiKey ?? ""
        print("🔵 [VioSDK] Commerce apiKey=\(apiKey.prefix(8))...")

        guard let product = await CommerceProductFetcher.fetch(id: id) else {
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
            let options: [SlimOption]?
            struct SlimOption: Codable { let id: Int?; let name: String?; let value: String? }
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

        let query = "{ Channel { GetProductsByIds(product_ids: [\(id)]) { id title images { url order } price { amount amount_incl_taxes currency_code } } } }"

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

        // Convertir a Product completo con defaults para campos no usados en overlay
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
            let opts = (v.options ?? []).map { o in
                VariantOption(id: String(o.id ?? 0), name: o.name ?? "", value: o.value ?? "")
            }
            return Variant(id: String(v.id ?? 0), title: v.title ?? "", quantity: v.quantity, price: vPrice, options: opts, barcode: nil, sku: nil, images: nil)
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
