//
//  TV2DemoCartIntentLogging.swift
//  tv2demo
//
//  One-line cart_intent traces: WebSocket vs UN notification.
//  Emojis: plug (socket) vs incoming envelope (notification); overlay stays bullseye in ContentView.
//

import Foundation
import VioCore

enum TV2DemoCartIntentLogging {
    /// Plug — WebSocket cart_intent (CartIntentEvent).
    private static let socketTag = "\u{1F50C} [TV2Demo]"
    /// Incoming envelope — APNs or local UNNotification (banner text = content.title/body).
    private static let notificationTag = "\u{1F4E8} [TV2Demo]"

    private static func oneLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func logSocketCartIntent(_ event: CartIntentEvent, delivery: CartIntentWebSocketDeliveryInfo) {
        let id = event.productId ?? "nil"
        let name = oneLine(event.productName ?? "nil")
        let title = oneLine(event.notificationTitle ?? "nil")
        let body = oneLine(event.notificationBody ?? "nil")
        let cid = event.campaignId.map(String.init) ?? "nil"
        let ws = delivery.socketConnected ? "connected" : "disconnected"
        print(
            "\(socketTag) cart_intent socket id=\(id) campaignId=\(cid) ws=\(ws) wsCampaignId=\(delivery.campaignSocketId) localUN=\(delivery.localNotificationSummary) name=\(name) notifTitle=\(title) notifBody=\(body)",
        )
    }

    static func logNotificationCartIntent(phase: String, contentTitle: String, contentBody: String, userInfo: [AnyHashable: Any]) {
        let top = userInfo as? [String: Any] ?? [:]
        let pid = (top[CartIntentNotificationKeys.productId] as? String)
            ?? (top["productId"] as? String)
            ?? "nil"
        let pname = oneLine(
            (top[CartIntentNotificationKeys.productName] as? String)
                ?? (top["productName"] as? String)
                ?? "nil",
        )
        let t = oneLine(contentTitle)
        let b = oneLine(contentBody)
        print("\(notificationTag) cart_intent notification \(phase) delegate id=\(pid) productName=\(pname) contentTitle=\(t) contentBody=\(b)")
    }
}
