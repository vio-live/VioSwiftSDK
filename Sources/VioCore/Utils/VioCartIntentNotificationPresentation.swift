import Foundation

#if canImport(UserNotifications)
import UserNotifications

/// Options to pass to `UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:)`
/// so **remote** and **local** `cart_intent` notifications show a banner while the app is in the foreground.
public enum VioCartIntentNotificationPresentation {

    /// Banner, sound, and Notification Center list (iOS 14+). Use for `cart_intent` when you want parity with background delivery.
    public static func willPresentOptions() -> UNNotificationPresentationOptions {
        if #available(iOS 14.0, macOS 11.0, *) {
            return [.banner, .sound, .list]
        }
        return [.alert, .sound]
    }

    /// Default options for non–cart_intent notifications in `willPresent`.
    public static func defaultWillPresentOptions() -> UNNotificationPresentationOptions {
        willPresentOptions()
    }
}
#endif
