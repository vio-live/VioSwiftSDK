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

    private func logPayload(_ userInfo: [AnyHashable: Any], phase: String) {
        let ns = userInfo as NSDictionary
        if JSONSerialization.isValidJSONObject(ns),
           let data = try? JSONSerialization.data(withJSONObject: ns, options: [.prettyPrinted, .sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            print("🎯 [TV2Demo] Notificación [\(phase)] payload JSON:\n\(json)")
        } else {
            print("🎯 [TV2Demo] Notificación [\(phase)] payload: \(userInfo)")
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
