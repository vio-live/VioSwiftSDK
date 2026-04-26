//
//  TV2NotificationCenterDelegate.swift
//  tv2demo
//
//  cart_intent (push): banner in foreground; in background the system shows automatically. Taps → CampaignManager.
//

import Foundation
import UserNotifications
import VioCore

final class TV2NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {

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

    private func logPayload(_ userInfo: [AnyHashable: Any], phase: String) {
        let safe = redactNotificationPayload(userInfo)
        if JSONSerialization.isValidJSONObject(safe),
           let data = try? JSONSerialization.data(withJSONObject: safe, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            print("🎯 [TV2Demo] Notificación [\(phase)] payload JSON (redactado):\n\(json)")
        } else {
            print("🎯 [TV2Demo] Notificación [\(phase)] payload (redactado): \(safe)")
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let info = notification.request.content.userInfo
        logPayload(info, phase: "willPresent(foreground)")
        if CampaignManager.isVioCartIntentNotificationUserInfo(info) {
            // Suppress the foreground banner when the same activation was just
            // dispatched via WebSocket — the in-app overlay already handles it,
            // a banner on top would be the redundant 2nd-of-N notifications the
            // user complained about. Background delivery is unaffected (this
            // delegate isn't called when the app is backgrounded).
            if let activationId = activationIdFromUserInfo(info),
               CampaignManager.shared.wasActivationRecentlyDispatched(activationId) {
                print("🎯 [TV2Demo] Notificación willPresent → suprimida (activationId=\(activationId) ya despachado por WS, overlay activo)")
                completionHandler([])
                return
            }
            print("🎯 [TV2Demo] Notificación willPresent → Vio cart_intent — discoverCampaigns + handlePush (overlay + commerce)")
            Task { @MainActor in
                await CampaignManager.shared.discoverCampaigns(broadcastId: nil)
                await CampaignManager.shared.ensureCommerceBootstrapApplied()
                CampaignManager.shared.handlePushNotificationUserInfo(info)
                print("🎯 [TV2Demo] Notificación willPresent → handlePush terminado (revisa logs [CampaignManager] / [ProductService])")
            }
            completionHandler(VioCartIntentNotificationPresentation.willPresentOptions())
            return
        }
        completionHandler(VioCartIntentNotificationPresentation.defaultWillPresentOptions())
    }

    /// Pulls `activation_id` from the canonical envelope (`vio_payload.activation_id`)
    /// or the legacy flat key. Used to consult the recently-dispatched cache before
    /// presenting a foreground banner.
    private func activationIdFromUserInfo(_ userInfo: [AnyHashable: Any]) -> Int? {
        if let payload = userInfo["vio_payload"] as? [String: Any] {
            if let n = payload["activation_id"] as? Int { return n }
            if let n = payload["activationId"] as? Int { return n }
            if let s = payload["activation_id"] as? String, let n = Int(s) { return n }
        }
        if let n = userInfo["vio_cartIntent_activationId"] as? Int { return n }
        if let s = userInfo["vio_cartIntent_activationId"] as? String, let n = Int(s) { return n }
        if let n = userInfo["activation_id"] as? Int { return n }
        if let s = userInfo["activation_id"] as? String, let n = Int(s) { return n }
        return nil
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        logPayload(userInfo, phase: "didReceive(tap)")
        guard CampaignManager.isVioCartIntentNotificationUserInfo(userInfo) else {
            print("🎯 [TV2Demo] Notificación tap → no es cart_intent Vio (ignorado para overlay)")
            completionHandler()
            return
        }

        print("🎯 [TV2Demo] Notificación tap → Vio cart_intent — discoverCampaigns + handlePush (commerce)")
        Task { @MainActor in
            await CampaignManager.shared.discoverCampaigns(broadcastId: nil)
            await CampaignManager.shared.ensureCommerceBootstrapApplied()
            CampaignManager.shared.handlePushNotificationUserInfo(userInfo)
            print("🎯 [TV2Demo] Notificación tap → handlePush terminado")
        }
        completionHandler()
    }
}
