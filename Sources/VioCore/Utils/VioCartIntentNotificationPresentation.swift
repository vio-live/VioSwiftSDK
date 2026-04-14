import Foundation

#if canImport(UserNotifications)
import UserNotifications

/// Options to pass to `UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:)`
/// so **remote** and **local** Vio notifications show a banner while the app is in the foreground.
public enum VioCartIntentNotificationPresentation {

    /// Banner, sound, and Notification Center list (iOS 14+). Use for `cart_intent` when you want parity with background delivery.
    public static func willPresentOptions() -> UNNotificationPresentationOptions {
        if #available(iOS 14.0, macOS 11.0, *) {
            return [.banner, .sound, .list]
        }
        return [.alert, .sound]
    }

    /// Resolves ``CampaignManager/resolvedVioEventType(from:)`` and returns presentation options for that `vio_event_type`. Extend the `switch` when adding ``VioPushEventType`` cases.
    public static func willPresentOptions(userInfo: [AnyHashable: Any]) -> UNNotificationPresentationOptions {
        willPresentOptions(forEventType: CampaignManager.resolvedVioEventType(from: userInfo))
    }

    /// Per-event presentation. Unknown types use the same options as ``defaultWillPresentOptions()`` until customized.
    public static func willPresentOptions(forEventType eventType: String?) -> UNNotificationPresentationOptions {
        guard let eventType else { return defaultWillPresentOptions() }
        switch eventType {
        case VioPushEventType.cartIntent.rawValue:
            return willPresentOptions()
        default:
            return defaultWillPresentOptions()
        }
    }

    /// Default options for notifications that are not handled as a specific Vio type, or when `userInfo` cannot be classified.
    public static func defaultWillPresentOptions() -> UNNotificationPresentationOptions {
        willPresentOptions()
    }
}
#endif
