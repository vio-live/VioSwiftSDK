import Foundation
import VioCore

/// WebSocket Manager for Campaign Lifecycle Events
@MainActor
public class CampaignWebSocketManager: ObservableObject {
    
    // MARK: - Properties
    private let campaignId: Int
    private let baseURL: String
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5
    private var isConnected: Bool = false
    
    // MARK: - Event Callbacks
    public var onCampaignStarted: ((CampaignStartedEvent) -> Void)?
    public var onCampaignEnded: ((CampaignEndedEvent) -> Void)?
    public var onCampaignPaused: ((CampaignPausedEvent) -> Void)?
    public var onCampaignResumed: ((CampaignResumedEvent) -> Void)?
    public var onComponentStatusChanged: ((ComponentStatusChangedEvent) -> Void)?
    public var onComponentConfigUpdated: ((ComponentConfigUpdatedEvent) -> Void)?
    public var onConnectionStatusChanged: ((Bool) -> Void)?
    
    // MARK: - Initialization
    public init(campaignId: Int, baseURL: String) {
        self.campaignId = campaignId
        self.baseURL = baseURL
        self.urlSession = URLSession(configuration: .default)
    }
    
    // MARK: - Connection Management
    
    /// Connect to campaign WebSocket
    public func connect() async {
        // Build WebSocket URL
        let wsURLString = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        let urlString = "\(wsURLString)/ws/\(campaignId)"
        
        guard let url = URL(string: urlString) else {
            VioLogger.error("Invalid WebSocket URL: \(urlString) - Base URL: \(baseURL), Campaign ID: \(campaignId)", component: "CampaignWebSocket")
            return
        }
        
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
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        // Wait a moment for connection to establish
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isConnected = true
        reconnectAttempts = 0 // Reset reconnect attempts on successful connection
        onConnectionStatusChanged?(true)
        
        // Start listening for messages in a separate task so it doesn't block
        // URLSessionWebSocketTask handles keep-alive automatically
        Task {
            await listenForMessages()
        }
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
                
            default:
                VioLogger.warning("Unknown event type: \(eventType)", component: "CampaignWebSocket")
            }
        } catch {
            VioLogger.error("Failed to decode \(eventType): \(error) - Raw message: \(text)", component: "CampaignWebSocket")
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

