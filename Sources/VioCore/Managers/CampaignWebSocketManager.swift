import Foundation
import UserNotifications

#if canImport(UIKit) && os(iOS)
import UIKit
#endif

/// WebSocket Manager for Campaign Lifecycle Events
@MainActor
public class CampaignWebSocketManager: NSObject, ObservableObject {
    
    // MARK: - Properties
    private let campaignId: Int
    private let baseURL: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5
    private var isConnected: Bool = false
    private var pendingRequest: URLRequest?
    
    // MARK: - Event Callbacks
    public var onCampaignStarted: ((CampaignStartedEvent) -> Void)?
    public var onCampaignEnded: ((CampaignEndedEvent) -> Void)?
    public var onCampaignPaused: ((CampaignPausedEvent) -> Void)?
    public var onCampaignResumed: ((CampaignResumedEvent) -> Void)?
    public var onComponentStatusChanged: ((ComponentStatusChangedEvent) -> Void)?
    public var onComponentConfigUpdated: ((ComponentConfigUpdatedEvent) -> Void)?
    public var onConnectionStatusChanged: ((Bool) -> Void)?
    /// Called when backend triggers lineup display. Carries the video timestamp and optional broadcastId.
    public var onLineupShow: ((LineupShowEvent) -> Void)?
    /// Called when backend sends a cart_intent event for this user.
    public var onCartIntent: ((CartIntentEvent) -> Void)?
    
    /// Optional user ID for WS identification and URL routing.
    /// When set, appended as `?userId=<uid>` to the WS URL and sent via `identify` message post-connect.
    /// Set via `CampaignManager.shared.userId` before connecting.
    public var userId: String?
    
    // MARK: - Initialization
    public init(campaignId: Int, baseURL: String, userId: String? = nil) {
        self.campaignId = campaignId
        self.baseURL = baseURL
        self.userId = userId
        super.init()
        self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        
        // Request local notification permission so cart_intent alerts can fire
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                VioLogger.error("Notification permission error: \(error)", component: "CampaignWebSocket")
            } else {
                VioLogger.debug("Notification permission granted: \(granted)", component: "CampaignWebSocket")
            }
        }
    }
    
    // MARK: - Connection Management
    
    /// Connect to campaign WebSocket
    public func connect() async {
        // Build WebSocket URL — uses VioConfiguration.wsBaseURL (already wss://)
        let wsBase = VioConfiguration.shared.wsBaseURL
        var urlString = "\(wsBase)/ws/\(campaignId)"
        if let uid = userId, !uid.isEmpty {
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&+=")
            let enc = uid.addingPercentEncoding(withAllowedCharacters: allowed) ?? uid
            urlString += "?userId=\(enc)"
        }
        
        guard let url = URL(string: urlString) else {
            VioLogger.error("Invalid WebSocket URL: \(urlString) - Base URL: \(baseURL), Campaign ID: \(campaignId)", component: "CampaignWebSocket")
            return
        }
        
        print("🎯 [CampaignWebSocket] connect → \(urlString)")
        print("🎯 [CampaignWebSocket] connect    esperado: handshake WebSocket OK; luego envío identify con userId si aplica")
        VioLogger.debug("Connecting to: \(urlString) - Base URL: \(baseURL), Campaign ID: \(campaignId)", component: "CampaignWebSocket")
        
        // Create URLRequest with potential authentication headers
        var request = URLRequest(url: url)
        request.timeoutInterval = 10.0
        
        // Add API key to headers if available
        let config = VioConfiguration.shared
        if !config.apiKey.isEmpty {
            request.setValue(config.apiKey, forHTTPHeaderField: "X-API-Key")
            VioLogger.debug("Using API Key: \(config.apiKey.prefix(8))...", component: "CampaignWebSocket")
        }
        
        // Guard: skip if already connected and running — prevents double-connect from
        // simultaneous onAppear calls (ContentView + TV2VideoPlayer both call discoverCampaigns)
        if let existing = webSocketTask, existing.state == .running {
            VioLogger.debug("connect() skipped — task already running (state: \(existing.state.rawValue))", component: "CampaignWebSocket")
            return
        }
        
        // Cancel any existing task before creating a new one
        // Without this, the old task fires Code=57 during reconnect and creates a loop
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        
        pendingRequest = request
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        // Connection established confirmed via URLSessionWebSocketDelegate
        // (didOpenWithProtocol fires when handshake completes)
    }
    
    /// Disconnect from WebSocket
    public func disconnect() {
        VioLogger.debug("Disconnecting from campaign \(campaignId)", component: "CampaignWebSocket")
        
        isConnected = false
        stopReconnectTimer()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        onConnectionStatusChanged?(false)
    }
    
    // MARK: - Message Handling
    
    private func listenForMessages() async {
        VioLogger.debug("Started listening for messages...", component: "CampaignWebSocket")
        
        while let webSocketTask = webSocketTask, isConnected {
            do {
                let message = try await webSocketTask.receive()
                
                switch message {
                case .string(let text):
                    VioLogger.debug("Received string message: \(text.prefix(100))", component: "CampaignWebSocket")
                    await handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        VioLogger.debug("Received data message: \(text.prefix(100))", component: "CampaignWebSocket")
                        await handleMessage(text)
                    } else {
                        VioLogger.warning("Received binary data (unable to decode)", component: "CampaignWebSocket")
                    }
                @unknown default:
                    VioLogger.warning("Unknown message type", component: "CampaignWebSocket")
                }
                
                // Continue listening - the while loop will automatically continue
                
            } catch {
                VioLogger.error("WebSocket error: \(error)", component: "CampaignWebSocket")
                
                // Check if we're still supposed to be connected
                guard isConnected else {
                    VioLogger.debug("Connection closed intentionally", component: "CampaignWebSocket")
                    break
                }
                
                // Check if it's a connection error that we should retry
                if let urlError = error as? URLError {
                    VioLogger.debug("Error code: \(urlError.code.rawValue), Error description: \(urlError.localizedDescription)", component: "CampaignWebSocket")
                    
                    // Don't retry for certain errors (like authentication failures)
                    if urlError.code == .userAuthenticationRequired || urlError.code == .userCancelledAuthentication {
                        VioLogger.warning("Authentication error - stopping reconnection attempts", component: "CampaignWebSocket")
                        isConnected = false
                        onConnectionStatusChanged?(false)
                        return
                    }
                }
                
                // Connection lost - try to reconnect
                isConnected = false
                onConnectionStatusChanged?(false)
                await attemptReconnect()
                break
            }
        }
        
        VioLogger.debug("Stopped listening for messages", component: "CampaignWebSocket")
    }
    
    private func handleMessage(_ text: String) async {
        VioLogger.debug("Raw message received: \(text.prefix(200))", component: "CampaignWebSocket")
        
        guard let data = text.data(using: .utf8) else {
            VioLogger.error("Invalid message data", component: "CampaignWebSocket")
            return
        }
        
        // Parse event type first
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = json["type"] as? String else {
            VioLogger.error("Failed to parse event type - Raw JSON: \(text)", component: "CampaignWebSocket")
            return
        }
        
        VioLogger.debug("Received event: \(eventType)", component: "CampaignWebSocket")
        
        // Handle based on event type
        do {
            switch eventType {
            case "campaign_started":
                let event = try JSONDecoder().decode(CampaignStartedEvent.self, from: data)
                VioLogger.success("Decoded campaign_started event", component: "CampaignWebSocket")
                onCampaignStarted?(event)
                
            case "campaign_ended":
                let event = try JSONDecoder().decode(CampaignEndedEvent.self, from: data)
                VioLogger.success("Decoded campaign_ended event", component: "CampaignWebSocket")
                onCampaignEnded?(event)
                
            case "campaign_paused":
                let event = try JSONDecoder().decode(CampaignPausedEvent.self, from: data)
                VioLogger.success("Decoded campaign_paused event", component: "CampaignWebSocket")
                onCampaignPaused?(event)
                
            case "campaign_resumed":
                let event = try JSONDecoder().decode(CampaignResumedEvent.self, from: data)
                VioLogger.success("Decoded campaign_resumed event", component: "CampaignWebSocket")
                onCampaignResumed?(event)
                
            case "component_status_changed":
                let event = try JSONDecoder().decode(ComponentStatusChangedEvent.self, from: data)
                VioLogger.success("Decoded component_status_changed event", component: "CampaignWebSocket")
                onComponentStatusChanged?(event)
                
            case "component_config_updated":
                let event = try JSONDecoder().decode(ComponentConfigUpdatedEvent.self, from: data)
                VioLogger.success("Decoded component_config_updated event", component: "CampaignWebSocket")
                onComponentConfigUpdated?(event)
                
            case "config:updated":
                // Handle config update event for dynamic configuration
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let campaignId = json["campaignId"] as? Int,
                   let sections = json["sections"] as? [String] {
                    // Try broadcastId first, fallback to matchId for backward compatibility
                    let broadcastId = json["broadcastId"] as? String ?? json["matchId"] as? String
                    DynamicConfigurationManager.shared.handleConfigUpdateEvent(
                        campaignId: campaignId,
                        broadcastId: broadcastId,
                        sections: sections
                    )
                    VioLogger.success("Handled config:updated event for campaignId: \(campaignId)", component: "CampaignWebSocket")
                } else {
                    VioLogger.warning("Invalid config:updated event format", component: "CampaignWebSocket")
                }
                
            case "lineup_show":
                let event = try JSONDecoder().decode(LineupShowEvent.self, from: data)
                VioLogger.success("Decoded lineup_show event (videoTimestamp: \(event.videoTimestamp))", component: "CampaignWebSocket")
                onLineupShow?(event)
                
            case "cart_intent":
                let event = try JSONDecoder().decode(CartIntentEvent.self, from: data)
                VioLogger.success("Decoded cart_intent event (productName: \(event.productName ?? "unknown"))", component: "CampaignWebSocket")
                onCartIntent?(event)
                scheduleCartIntentNotification(for: event)

            case "ping":
                // App-level heartbeat — respond immediately with pong
                await sendPong()
                
            default:
                VioLogger.warning("Unknown event type: \(eventType)", component: "CampaignWebSocket")
            }
        } catch {
            VioLogger.error("Failed to decode \(eventType): \(error) - Raw message: \(text)", component: "CampaignWebSocket")
        }
    }
    
    // MARK: - Outbound Messages
    
    /// Responds to server-initiated app-level ping with `{ "type": "pong" }`.
    private func sendPong() async {
        guard isConnected, let task = webSocketTask else {
            VioLogger.debug("sendPong skipped — socket not connected", component: "CampaignWebSocket")
            return
        }
        let payload: [String: String] = ["type": "pong"]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        do {
            try await task.send(.string(text))
            VioLogger.debug("Sent pong", component: "CampaignWebSocket")
        } catch {
            VioLogger.error("Failed to send pong: \(error)", component: "CampaignWebSocket")
        }
    }
    
    /// Sends `{ "type": "identify", "userId": "..." }` to the backend if `userId` is set.
    /// Registers this WS connection in the server's `wsUserMap` for targeted notifications.
    private func sendIdentifyIfNeeded() async {
        guard isConnected, let task = webSocketTask else {
            VioLogger.debug("sendIdentify skipped — socket not connected", component: "CampaignWebSocket")
            return
        }
        guard let userId = userId, !userId.isEmpty else {
            VioLogger.debug("No userId set — skipping identify", component: "CampaignWebSocket")
            return
        }
        let payload: [String: String] = ["type": "identify", "userId": userId]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else {
            VioLogger.error("Failed to encode identify payload", component: "CampaignWebSocket")
            return
        }
        do {
            try await task.send(.string(text))
            print("🎯 [CampaignWebSocket] identify → enviado \(text) (servidor registra userId en wsUserMap)")
            VioLogger.debug("Sent identify for userId: \(userId)", component: "CampaignWebSocket")
        } catch {
            VioLogger.error("Failed to send identify: \(error)", component: "CampaignWebSocket")
            // Mark as disconnected so listenForMessages doesn't start on a dead socket
            isConnected = false
        }
    }
    
    // MARK: - Local Notifications
    
    /// When the app is active, the in-app overlay already shows — skip local notification to avoid duplicate prompts.
    private func shouldSkipCartIntentLocalNotification() -> Bool {
        #if canImport(UIKit) && os(iOS)
        return UIApplication.shared.applicationState == .active
        #else
        return false
        #endif
    }
    
    /// Fires a local notification when a cart_intent is received (for users in background or after switching apps).
    private func scheduleCartIntentNotification(for event: CartIntentEvent) {
        if shouldSkipCartIntentLocalNotification() {
            VioLogger.debug("cart_intent: skipping local notification — app is active", component: "CampaignWebSocket")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "Tienes un artículo esperando"
        content.body = event.productName ?? "Un producto está listo para añadir al carrito"
        content.sound = .default
        var info: [String: Any] = [
            VioNotificationUserInfoKeys.notificationVersion: 1,
            VioNotificationUserInfoKeys.eventType: VioPushEventType.cartIntent.rawValue,
            CartIntentNotificationKeys.kind: CartIntentNotificationKeys.kindValueCartIntent,
        ]
        if let pid = event.productId, !pid.isEmpty { info[CartIntentNotificationKeys.productId] = pid }
        if let name = event.productName { info[CartIntentNotificationKeys.productName] = name }
        if let cid = event.campaignId { info[CartIntentNotificationKeys.campaignId] = cid }
        content.userInfo = info
        
        let request = UNNotificationRequest(
            identifier: "cart_intent_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                VioLogger.error("Failed to schedule cart_intent notification: \(error)", component: "CampaignWebSocket")
            } else {
                VioLogger.success("cart_intent notification scheduled", component: "CampaignWebSocket")
            }
        }
    }
    
    // MARK: - Reconnection Logic
    
    private func attemptReconnect() async {
        guard reconnectAttempts < maxReconnectAttempts else {
            VioLogger.error("Max reconnection attempts reached", component: "CampaignWebSocket")
            onConnectionStatusChanged?(false)
            return
        }
        
        reconnectAttempts += 1
        let delay = min(30.0, pow(2.0, Double(reconnectAttempts))) // Exponential backoff, max 30s
        
        VioLogger.debug("Reconnecting in \(delay) seconds (attempt \(reconnectAttempts)/\(maxReconnectAttempts))", component: "CampaignWebSocket")
        
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        await connect()
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0
    }
}

// MARK: - URLSessionWebSocketDelegate
extension CampaignWebSocketManager: URLSessionWebSocketDelegate {
    
    /// Fires when the WebSocket handshake completes — real connection confirmed.
    public nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor in
            // Guard against stale callbacks from previously cancelled tasks
            // Without this, a cancelled task can still fire didOpen and start a second listenForMessages loop
            guard webSocketTask === self.webSocketTask else {
                VioLogger.debug("Ignoring didOpen for stale webSocketTask", component: "CampaignWebSocket")
                return
            }
            print("🎯 [CampaignWebSocket] ← WebSocket abierto campaignId=\(self.campaignId) (equivalente HTTP 101 Switching Protocols)")
            self.isConnected = true
            self.reconnectAttempts = 0
            self.onConnectionStatusChanged?(true)
            
            // Start receive loop FIRST — URLSessionWebSocketTask requires receive() to be active
            // before send() works on iOS. Without this, sendIdentifyIfNeeded fails with Code=57.
            Task {
                await self.listenForMessages()
            }
            
            // Now send identify — receive() is already active
            await self.sendIdentifyIfNeeded()
            
            // If identify failed, isConnected was set to false — schedule reconnect
            // (listenForMessages will also exit since isConnected=false)
            if !self.isConnected {
                VioLogger.debug("identify failed post-open — scheduling reconnect", component: "CampaignWebSocket")
                await self.attemptReconnect()
            }
        }
    }
    
    /// Fires when the server closes the connection.
    public nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        Task { @MainActor in
            // Guard against stale callbacks from previously cancelled tasks
            guard webSocketTask === self.webSocketTask else {
                VioLogger.debug("Ignoring didClose for stale webSocketTask", component: "CampaignWebSocket")
                return
            }
            print("🎯 [CampaignWebSocket] WS closed (code: \(closeCode.rawValue), reason: \(reasonStr)) campaignId: \(self.campaignId)")
            guard self.isConnected else { return }
            self.isConnected = false
            self.onConnectionStatusChanged?(false)
            await self.attemptReconnect()
        }
    }
}

