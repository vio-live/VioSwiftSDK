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
        #if DEBUG
        if JSONSerialization.isValidJSONObject(safe),
           let data = try? JSONSerialization.data(withJSONObject: safe, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            print("[TV2Demo] notification [\(phase)] payload JSON (redacted):\n\(json)")
        } else {
            print("[TV2Demo] notification [\(phase)] payload (redacted): \(safe)")
        }
        #else
        let keys = safe.keys.map { String(describing: $0) }.sorted()
        print("[TV2Demo] notification [\(phase)] keys=\(keys)")
        #endif
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let info = notification.request.content.userInfo
        logPayload(info, phase: "willPresent(foreground)")
        if CampaignManager.isVioCartIntentNotificationUserInfo(info) {
            print("[TV2Demo] notification willPresent cart_intent")
            Task { @MainActor in
                await CampaignManager.shared.discoverCampaigns(broadcastId: nil)
                await CampaignManager.shared.ensureCommerceBootstrapApplied()
                CampaignManager.shared.handlePushNotificationUserInfo(info)
            }
            completionHandler(VioCartIntentNotificationPresentation.willPresentOptions())
            return
        }
        completionHandler(VioCartIntentNotificationPresentation.defaultWillPresentOptions())
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        logPayload(userInfo, phase: "didReceive(tap)")
        guard CampaignManager.isVioCartIntentNotificationUserInfo(userInfo) else {
            print("[TV2Demo] notification tap ignored (not Vio cart_intent)")
            completionHandler()
            return
        }

        print("[TV2Demo] notification tap cart_intent")
        Task { @MainActor in
            await CampaignManager.shared.discoverCampaigns(broadcastId: nil)
            await CampaignManager.shared.ensureCommerceBootstrapApplied()
            CampaignManager.shared.handlePushNotificationUserInfo(userInfo)
        }
        completionHandler()
    }
}
