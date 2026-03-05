import Foundation
#if canImport(UIKit)
import UIKit

/// Extensión pública para abrir un producto desde una push notification.
public enum VioSDK {

    @MainActor
    public static func openProduct(id: String) async {
        guard VioConfiguration.shared.shouldUseSDK else {
            VioLogger.warning("⚠️ [VioSDK] SDK no configurado — llamar configure() primero")
            return
        }

        VioLogger.info("📦 [VioSDK] openProduct(\(id)) — fetching from Commerce")

        guard let product = await CommerceProductFetcher.fetch(id: id) else {
            VioLogger.error("❌ [VioSDK] No se pudo obtener producto \(id)")
            return
        }

        VioLogger.info("✅ [VioSDK] Producto listo: \(product.title) — presentando overlay")

        NotificationCenter.default.post(
            name: .vioOpenProductOverlay,
            object: nil,
            userInfo: ["product": product]
        )

        VioLogger.info("📤 [VioSDK] Evento vioOpenProductOverlay emitido")
    }
}

public extension Notification.Name {
    static let vioOpenProductOverlay = Notification.Name("live.vio.openProductOverlay")
}

private enum CommerceProductFetcher {
    static func fetch(id: String) async -> Product? {
        let baseURL = "https://graph-ql-dev.vio.live/graphql"
        let apiKey = VioConfiguration.shared.dynamicCommerceConfig?.apiKey ?? ""

        guard !apiKey.isEmpty, let url = URL(string: baseURL) else { return nil }

        let query = """
        { Channel { GetProductsByIds(product_ids: [\(id)]) {
            id title
            images { url order }
            price { amount amount_incl_taxes currency_code }
        } } }
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["query": query])

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }

        struct GQLResponse: Codable {
            struct Data: Codable {
                struct Channel: Codable {
                    let GetProductsByIds: [Product]?
                }
                let Channel: Channel?
            }
            let data: Data?
        }

        return (try? JSONDecoder().decode(GQLResponse.self, from: data))?.data?.Channel?.GetProductsByIds?.first
    }
}
#endif
