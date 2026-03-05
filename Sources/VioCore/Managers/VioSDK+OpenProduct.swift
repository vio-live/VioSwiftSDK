import Foundation
#if canImport(UIKit)
import UIKit

/// Extensión pública para abrir un producto directamente desde una push notification.
/// Uso: llamar desde el AppDelegate cuando el usuario toca la notificación.
///
/// ```swift
/// // En AppDelegate o SwiftUI App:
/// func userNotificationCenter(_ center: UNUserNotificationCenter,
///     didReceive response: UNNotificationResponse) async {
///     let userInfo = response.notification.request.content.userInfo
///     if let productId = userInfo["productId"] as? String,
///        (userInfo["action"] as? String) == "open_product" {
///         await VioSDK.openProduct(id: productId)
///     }
/// }
/// ```
public enum VioSDK {

    /// Abre el overlay de detalle de producto con Apple Pay listo.
    /// Fetcha los datos reales de Commerce y presenta el overlay sobre la ventana activa.
    @MainActor
    public static func openProduct(id: String) async {
        guard VioConfiguration.shared.shouldUseSDK else {
            VioLogger.log("⚠️ [VioSDK] SDK no configurado — llamar configure() primero", level: .warning)
            return
        }

        VioLogger.log("📦 [VioSDK] openProduct(\(id)) — fetching from Commerce", level: .info)

        guard let product = await CommerceProductFetcher.fetch(id: id) else {
            VioLogger.log("❌ [VioSDK] No se pudo obtener producto \(id)", level: .error)
            return
        }

        VioLogger.log("✅ [VioSDK] Producto listo: \(product.name) — presentando overlay", level: .info)

        // Presentar sobre la ventana activa
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            VioLogger.log("❌ [VioSDK] No se encontró ventana activa", level: .error)
            return
        }

        // Notificar al SDK para abrir el overlay
        NotificationCenter.default.post(
            name: .vioOpenProductOverlay,
            object: nil,
            userInfo: ["product": product]
        )

        VioLogger.log("📤 [VioSDK] Evento vioOpenProductOverlay emitido", level: .info)
    }
}

// MARK: - Notification name
public extension Notification.Name {
    static let vioOpenProductOverlay = Notification.Name("live.vio.openProductOverlay")
}

// MARK: - Commerce fetcher (lightweight, reutiliza VioCommerceService si existe)
private enum CommerceProductFetcher {
    static func fetch(id: String) async -> Product? {
        let config = VioConfiguration.shared
        let baseURL = "https://graph-ql-dev.vio.live/graphql"
        let apiKey = config.dynamicCommerceConfig?.apiKey ?? ""

        guard !apiKey.isEmpty, let url = URL(string: baseURL) else { return nil }

        let query = """
        { Channel { GetProductById(id: "\(id)", countryCode: "NO", currencyCode: "NOK") {
            id name
            images { url order }
            price { amount amount_incl_taxes currency_code }
            variants { id title price inventory_quantity option_values { option_name value } }
        } } }
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["query": query])

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }

        // Parsear usando los modelos existentes del SDK
        struct GQLResponse: Codable {
            struct Data: Codable {
                struct Channel: Codable {
                    let GetProductById: Product?
                }
                let Channel: Channel?
            }
            let data: Data?
        }

        return (try? JSONDecoder().decode(GQLResponse.self, from: data))?.data?.Channel?.GetProductById
    }
}
#endif
