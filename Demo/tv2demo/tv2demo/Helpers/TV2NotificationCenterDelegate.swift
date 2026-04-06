//
//  TV2NotificationCenterDelegate.swift
//  tv2demo
//
//  Local notifications: show banner in foreground; route cart_intent taps to CampaignManager.
//

import Foundation
import UserNotifications
import VioCore

final class TV2NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let info = notification.request.content.userInfo
        if CampaignManager.isVioCartIntentNotificationUserInfo(info) {
            completionHandler([.banner, .sound])
            return
        }
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard CampaignManager.isVioCartIntentNotificationUserInfo(userInfo) else {
            completionHandler()
            return
        }

        Task { @MainActor in
            await CampaignManager.shared.discoverCampaigns(broadcastId: nil)
            CampaignManager.shared.handlePushNotificationUserInfo(userInfo)
        }
        completionHandler()
    }
}
