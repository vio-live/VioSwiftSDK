//
//  TV2NotificationCenterDelegate.swift
//  tv2demo
//
//  Vio notifications (vio_event_type / legacy cart_intent): foreground banner via VioCartIntentNotificationPresentation; tap / willPresent → CampaignManager.prepareForHandlingVioNotification + handlePushNotificationUserInfo.
//

import Foundation
import UserNotifications
import VioCore

private enum TV2DemoConsole {
    private static let tag = "\u{1F3AF} [TV2Demo]"
    static func log(_ message: String) {
        print("\(tag) \(message)")
    }
}

final class TV2NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Set `true` in DEBUG to print full redacted JSON for every notification (noisy).
    private static let debugVerboseNotificationPayload = false

    /// Evita volcar secretos a consola (apiKey, tokens, etc.); solo longitudes.
    private func redactNotificationPayload(_ userInfo: [AnyHashable: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in userInfo {
            let key = String(describing: k)
            let low = key.lowercased()
            if low.contains("apikey") || low.contains("api_key") || low.contains("token") || low.contains("secret")
                || low == "authorization" || low.contains("password") || low.contains("bearer")
            {
                if let s = v as? String { out[key] = "<redacted len=\(s.count)>" }
                else { out[key] = "<redacted>" }
            } else if let nested = v as? [AnyHashable: Any] {
                out[key] = redactNotificationPayload(nested)
            } else if let arr = v as? [Any] {
                out[key] = arr.map { elem -> Any in
                    if let d = elem as? [AnyHashable: Any] { return redactNotificationPayload(d) }
                    return elem
                }
            } else {
                out[key] = v
            }
        }
        return out
    }

    /// Pretty JSON del payload al **tocar** la notificación (DEBUG). Claves sensibles redactadas.
    private func printRedactedTapPayload(_ userInfo: [AnyHashable: Any]) {
        #if DEBUG
        let safe = redactNotificationPayload(userInfo)
        if JSONSerialization.isValidJSONObject(safe),
           let data = try? JSONSerialization.data(withJSONObject: safe, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            TV2DemoConsole.log("notification tap payload (redacted JSON):\n\(json)")
        } else {
            TV2DemoConsole.log("notification tap payload (redacted): \(safe)")
        }
        #endif
    }

    /// Resumen de una línea para `cart_intent` (incluye `vio_payload` vía ``CartIntentEvent/from(userInfo:)``).
    private func cartIntentSummaryLine(_ userInfo: [AnyHashable: Any]) -> String {
        if let e = CartIntentEvent.from(userInfo: userInfo) {
            let title = e.notificationTitle ?? "nil"
            let bodyLen = e.notificationBody?.count ?? 0
            return "cart_intent productId=\(e.productId ?? "nil") campaignId=\(e.campaignId.map(String.init) ?? "nil") notifTitle=\(title) notifBodyLen=\(bodyLen)"
        }
        let top = userInfo as? [String: Any] ?? [:]
        let pid = (top[CartIntentNotificationKeys.productId] as? String)
            ?? (top["productId"] as? String)
            ?? "nil"
        let cid = (top[CartIntentNotificationKeys.campaignId] as? Int).map(String.init)
            ?? (top["campaignId"] as? Int).map(String.init)
            ?? "nil"
        return "cart_intent (unparsed) productId=\(pid) campaignId=\(cid)"
    }

    private func logPayload(_ userInfo: [AnyHashable: Any], phase: String, isCartIntent: Bool) {
        #if DEBUG
        if Self.debugVerboseNotificationPayload {
            let safe = redactNotificationPayload(userInfo)
            if JSONSerialization.isValidJSONObject(safe),
               let data = try? JSONSerialization.data(withJSONObject: safe, options: [.prettyPrinted, .sortedKeys]),
               let json = String(data: data, encoding: .utf8) {
                TV2DemoConsole.log("notification [\(phase)] payload JSON (redacted):\n\(json)")
            } else {
                TV2DemoConsole.log("notification [\(phase)] payload (redacted): \(safe)")
            }
            return
        }
        #endif
        if isCartIntent {
            TV2DemoConsole.log("notification [\(phase)] \(cartIntentSummaryLine(userInfo))")
        } else {
            let safe = redactNotificationPayload(userInfo)
            let keys = safe.keys.map { String(describing: $0) }.sorted()
            TV2DemoConsole.log("notification [\(phase)] keys=\(keys)")
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let content = notification.request.content
        let info = content.userInfo
        let isVio = CampaignManager.isVioNotificationUserInfo(info)
        let isCart = CampaignManager.isVioCartIntentNotificationUserInfo(info)
        TV2DemoConsole.log(
            "notification inbound willPresent title=\"\(content.title)\" bodyLen=\(content.body.count) vio=\(isVio) cart_intent=\(isCart)",
        )
        logPayload(info, phase: "willPresent(foreground)", isCartIntent: isCart)
        guard isVio else {
            completionHandler(VioCartIntentNotificationPresentation.defaultWillPresentOptions())
            return
        }
        if isCart {
            let c = notification.request.content
            TV2DemoCartIntentLogging.logNotificationCartIntent(
                phase: "willPresent",
                contentTitle: c.title,
                contentBody: c.body,
                userInfo: info,
            )
        }
        Task { @MainActor in
            await CampaignManager.shared.prepareForHandlingVioNotification(broadcastId: nil)
            CampaignManager.shared.handlePushNotificationUserInfo(info)
        }
        completionHandler(VioCartIntentNotificationPresentation.willPresentOptions(userInfo: info))
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let content = response.notification.request.content
        let userInfo = content.userInfo
        let isVio = CampaignManager.isVioNotificationUserInfo(userInfo)
        let isCart = CampaignManager.isVioCartIntentNotificationUserInfo(userInfo)
        TV2DemoConsole.log(
            "notification inbound tap title=\"\(content.title)\" bodyLen=\(content.body.count) vio=\(isVio) cart_intent=\(isCart) action=\(response.actionIdentifier)",
        )
        logPayload(userInfo, phase: "didReceive(tap)", isCartIntent: isCart)
        #if DEBUG
        if !Self.debugVerboseNotificationPayload {
            printRedactedTapPayload(userInfo)
        }
        #endif
        guard isVio else {
            TV2DemoConsole.log("notification tap ignored (not Vio-shaped payload)")
            completionHandler()
            return
        }

        if isCart {
            let c = response.notification.request.content
            TV2DemoCartIntentLogging.logNotificationCartIntent(
                phase: "tap",
                contentTitle: c.title,
                contentBody: c.body,
                userInfo: userInfo,
            )
        }
        Task { @MainActor in
            await CampaignManager.shared.prepareForHandlingVioNotification(broadcastId: nil)
            CampaignManager.shared.handlePushNotificationUserInfo(userInfo)
        }
        completionHandler()
    }
}
