import UIKit
import UserNotifications
import VioCore
import VioUI

class VioAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        print("✅ [TV2Push] AppDelegate didFinishLaunching")
        return true
    }

    // MARK: - APNs token recibido
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        DeviceTokenManager.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DeviceTokenManager.shared.didFailToRegister(error: error)
    }

    // MARK: - Push notification recibida en foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Usuario toca la notificación → abrir producto
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        if let productId = userInfo["productId"] as? String,
           (userInfo["action"] as? String) == "open_product" {
            print("📲 [TV2Demo] Push tap — abriendo producto \(productId)")
            Task {
                await VioSDK.openProduct(id: productId)
            }
        }

        completionHandler()
    }
}
