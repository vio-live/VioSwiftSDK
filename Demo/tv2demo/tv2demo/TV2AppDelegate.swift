//
//  TV2AppDelegate.swift
//  tv2demo
//
//  Requests APNs permission and forwards the token to CampaignManager (zero-config register-device
//  after discoverCampaigns — see `CampaignManager.submitApnsDeviceTokenForVioRegister`).
//

import UIKit
import UserNotifications
import VioCore

private enum TV2DemoConsole {
    private static let tag = "\u{1F3AF} [TV2Demo]"
    static func log(_ message: String) {
        print("\(tag) \(message)")
    }
}

final class TV2AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let remote = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [AnyHashable: Any] {
            let isVio = CampaignManager.isVioNotificationUserInfo(remote)
            let isCart = CampaignManager.isVioCartIntentNotificationUserInfo(remote)
            TV2DemoConsole.log("App launched with remoteNotification payload vio=\(isVio) cart_intent=\(isCart)")
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                TV2DemoConsole.log("Notification permission not granted — partner push E2E will not work on device")
            }
        }
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        Task { @MainActor in
            CampaignManager.shared.suspendWebSocketForBackground()
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        Task { @MainActor in
            await CampaignManager.shared.resumeWebSocketIfNeeded()
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in
            CampaignManager.shared.submitApnsDeviceTokenForVioRegister(hex)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        TV2DemoConsole.log("APNs registration failed: \(error.localizedDescription)")
    }

    /// Logs when the system delivers a remote notification while the app runs (background/foreground). Banner alone may not call this unless `content-available` is set; tap uses ``UNUserNotificationCenterDelegate`` (`didReceive`).
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let isVio = CampaignManager.isVioNotificationUserInfo(userInfo)
        let isCart = CampaignManager.isVioCartIntentNotificationUserInfo(userInfo)
        let keys = userInfo.keys.map { String(describing: $0) }.sorted().joined(separator: ",")
        TV2DemoConsole.log("APNs didReceiveRemoteNotification vio=\(isVio) cart_intent=\(isCart) keys=[\(keys)]")
        if isCart, let e = CartIntentEvent.from(userInfo: userInfo) {
            TV2DemoConsole.log(
                "APNs cart_intent summary productId=\(e.productId ?? "nil") campaignId=\(e.campaignId.map(String.init) ?? "nil") notifTitle=\(e.notificationTitle ?? "nil")",
            )
        }
        completionHandler(.noData)
    }
}
