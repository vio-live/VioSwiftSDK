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
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("✅ [TV2Push] TOKEN RECIBIDO: \(token.prefix(20))...")
        DeviceTokenManager.shared.didRegister(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ [TV2Push] FALLÓ REGISTRO: \(error)")
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
        print("📲 [TV2Demo] Push tap — userInfo: \(userInfo)")

        // productId puede llegar como String o Int
        let productId: String?
        if let pid = userInfo["productId"] as? String {
            productId = pid
        } else if let pid = userInfo["productId"] as? Int {
            productId = String(pid)
        } else {
            productId = nil
        }

        let action = userInfo["action"] as? String
        print("📲 [TV2Demo] productId=\(productId ?? "nil") action=\(action ?? "nil")")

        if let productId = productId {
            print("📲 [TV2Demo] Guardando producto pendiente: \(productId)")
            Task { @MainActor in
                PushNavigationManager.shared.setPendingProduct(id: productId)
            }
        }

        completionHandler()
    }
}
