import Foundation

#if canImport(UserNotifications)
import UserNotifications

// MARK: - Copy (SDK defaults vs server)

/// Spanish fallbacks used **only** when the server does not send ``CartIntentEvent/notificationTitle`` / ``notificationBody``
/// (and there is no usable product name for the body).
///
/// **Where notification text comes from**
/// 1. **WebSocket / push payload:** ``CartIntentEvent/notificationTitle`` and ``notificationBody`` when present (see ``CartIntentNotificationKeys``).
/// 2. **Remote APNs:** ``CampaignManager`` merges `aps.alert.title` / `aps.alert.body` when building ``CartIntentEvent`` from `userInfo`.
/// 3. **SDK local notification (WebSocket path):** If (1) is empty, title uses ``CampaignManager/cartIntentLocalNotificationDefaultTitle`` if set, else ``VioCartIntentLocalNotificationCopy/defaultTitle``
///    (`"Tienes un artículo esperando"` — not "producto" in the title; if you see "producto" in the title, it came from the server or APNs).
/// 4. **Body:** product name, then ``CampaignManager/cartIntentLocalNotificationDefaultBody``, then ``VioCartIntentLocalNotificationCopy/defaultBodyWithoutProductName``.
public enum VioCartIntentLocalNotificationCopy {
    public static let defaultTitle = "Tienes un artículo esperando"
    public static let defaultBodyWithoutProductName = "Un producto está listo para añadir al carrito"
}

// MARK: - UNContent + userInfo

/// Shared construction of local notification content for `cart_intent` (WebSocket → banner parity with APNs).
public enum VioCartIntentLocalNotificationContentBuilder {
    /// Builds notification content. Pass overrides from ``CampaignManager`` when customizing defaults.
    public static func makeContent(
        for event: CartIntentEvent,
        defaultTitle: String? = nil,
        defaultBodyWhenNoProductName: String? = nil,
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let titleFallback = defaultTitle ?? VioCartIntentLocalNotificationCopy.defaultTitle
        let bodyFallback = defaultBodyWhenNoProductName ?? VioCartIntentLocalNotificationCopy.defaultBodyWithoutProductName

        let tTrim = event.notificationTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        content.title = tTrim.isEmpty ? titleFallback : tTrim

        let bTrim = event.notificationBody?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !bTrim.isEmpty {
            content.body = bTrim
        } else if let name = event.productName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.body = name
        } else {
            content.body = bodyFallback
        }
        content.sound = .default
        content.userInfo = notificationUserInfo(for: event)
        return content
    }

    /// Canonical `userInfo` for `cart_intent` (matches push / local contract).
    public static func notificationUserInfo(for event: CartIntentEvent) -> [String: Any] {
        let tTrim = event.notificationTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bTrim = event.notificationBody?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var info: [String: Any] = [
            VioNotificationUserInfoKeys.notificationVersion: 1,
            VioNotificationUserInfoKeys.eventType: VioPushEventType.cartIntent.rawValue,
            CartIntentNotificationKeys.kind: CartIntentNotificationKeys.kindValueCartIntent,
        ]
        if let pid = event.productId, !pid.isEmpty { info[CartIntentNotificationKeys.productId] = pid }
        if let name = event.productName { info[CartIntentNotificationKeys.productName] = name }
        if let cid = event.campaignId { info[CartIntentNotificationKeys.campaignId] = cid }
        if !tTrim.isEmpty { info[CartIntentNotificationKeys.notificationTitle] = tTrim }
        if !bTrim.isEmpty { info[CartIntentNotificationKeys.notificationBody] = bTrim }
        return info
    }
}
#endif
