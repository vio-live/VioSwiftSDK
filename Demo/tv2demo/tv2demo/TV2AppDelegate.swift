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

final class TV2AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                print("[TV2Demo] Notification permission not granted — partner push E2E will not work on device")
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
        if hex.count > 16 {
            print("[TV2Demo] APNs token len=\(hex.count) prefix=\(hex.prefix(8)) suffix=\(hex.suffix(8))")
        } else {
            print("[TV2Demo] APNs token len=\(hex.count)")
        }
        #if DEBUG
        print("[TV2Demo] APNs token (DEBUG full hex): \(hex)")
        #endif
        Task { @MainActor in
            CampaignManager.shared.submitApnsDeviceTokenForVioRegister(hex)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[TV2Demo] APNs registration failed: \(error.localizedDescription)")
    }
}
