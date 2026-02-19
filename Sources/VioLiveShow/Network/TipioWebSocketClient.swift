import Foundation
import Combine
import SocketIO

/// WebSocket client for real-time Tipio events
@MainActor
public class TipioWebSocketClient: NSObject, ObservableObject {
    
    // MARK: - Properties
    @Published public private(set) var isConnected = false
    @Published public private(set) var connectionStatus: ConnectionStatus = .disconnected
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private let baseUrl: String
    
    // Socket.IO
    private var socketManager: SocketManager?
    private var socket: SocketIOClient?
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts: Int
    private let heartbeatInterval: TimeInterval
    
    // Event publishers
    private let eventSubject = PassthroughSubject<TipioEvent, Never>()
    private let connectionSubject = PassthroughSubject<ConnectionStatus, Never>()
    private let liveEventSubject = PassthroughSubject<LiveStreamSocketEvent, Never>()
    
    public var eventPublisher: AnyPublisher<TipioEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    public var connectionPublisher: AnyPublisher<ConnectionStatus, Never> {
        connectionSubject.eraseToAnyPublisher()
    }

    public var liveEventPublisher: AnyPublisher<LiveStreamSocketEvent, Never> {
        liveEventSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Connection Status
    public enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting
        case error(String)
        
        public static func == (lhs: ConnectionStatus, rhs: ConnectionStatus) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected): return true
            case (.connecting, .connecting): return true
            case (.connected, .connected): return true
            case (.reconnecting, .reconnecting): return true
            case (.error(let lhsError), .error(let rhsError)): return lhsError == rhsError
            default: return false
            }
        }
        
        public var displayName: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting"
            case .connected: return "Connected"
            case .reconnecting: return "Reconnecting"
            case .error(let message): return "Error: \(message)"
            }
        }
    }
    
    // MARK: - Initialization
    public init(
        baseUrl: String,
        maxReconnectAttempts: Int = 5,
        heartbeatInterval: TimeInterval = 30
    ) {
        self.baseUrl = baseUrl
        self.maxReconnectAttempts = maxReconnectAttempts
        self.heartbeatInterval = heartbeatInterval
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
        
        super.init()
        
        print("🔌 [TipioWS] WebSocket client initialized")
    }
    
    // MARK: - Connection Management
    
    /// Connect to Tipio Socket.IO backend
    public func connect() {
        guard connectionStatus != .connecting && connectionStatus != .connected else {
            print("🔌 [TipioWS] Already connecting or connected")
            return
        }
        
        updateConnectionStatus(.connecting)
        
        // Prepare Socket.IO manager and client
        guard let (originURL, socketPath, namespace) = buildSocketIOConfig(from: baseUrl) else {
            updateConnectionStatus(.error("Invalid Socket.IO URL"))
            return
        }
        
        print("🔌 [TipioWS] Connecting (Socket.IO) to: \(originURL.absoluteString), path: \(socketPath), ns: \(namespace ?? "/")")
        
        let manager = SocketManager(
            socketURL: originURL,
            config: [
                .log(false),
                .compress,
                .path(socketPath)
            ]
        )
        self.socketManager = manager
        let client = (namespace != nil) ? manager.socket(forNamespace: namespace!) : manager.defaultSocket
        self.socket = client
        
        // Lifecycle events
        client.on(clientEvent: .connect) { [weak self] _, _ in
            print("✅ [TipioWS] Socket.IO connected")
            self?.updateConnectionStatus(.connected)
            self?.resetReconnectAttempts()
        }
        client.on(clientEvent: .error) { [weak self] data, _ in
            print("❌ [TipioWS] Socket.IO error: \(data)")
            self?.updateConnectionStatus(.error("Socket.IO error"))
        }
        client.on(clientEvent: .disconnect) { [weak self] _, _ in
            print("🔌 [TipioWS] Socket.IO disconnected")
            self?.updateConnectionStatus(.disconnected)
        }
        client.on(clientEvent: .reconnect) { [weak self] data, _ in
            print("🔄 [TipioWS] Socket.IO reconnect: \(data)")
            self?.updateConnectionStatus(.reconnecting)
        }
        client.on(clientEvent: .reconnectAttempt) { [weak self] data, _ in
            print("🔄 [TipioWS] Socket.IO reconnect attempt: \(data)")
            self?.updateConnectionStatus(.reconnecting)
        }
        
        // Known domain events
        self.registerDomainEventHandlers(on: client)
        
        // Catch-all (filtrado para evitar spam de logs)
        client.onAny { [weak self] event in
            self?.handleAnySocketEvent(event)
        }
        
        client.connect()
    }
    
    /// Disconnect from WebSocket
    public func disconnect() {
        print("🔌 [TipioWS] Disconnecting...")
        
        stopHeartbeat()
        stopReconnectTimer()
        
        socket?.disconnect()
        socket = nil
        socketManager = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        updateConnectionStatus(.disconnected)
    }
    
    /// Subscribe to events for a specific livestream
    public func subscribeToStream(_ streamId: Int) {
        guard isConnected else {
            print("❌ [TipioWS] Cannot subscribe - not connected")
            return
        }
        
        let payload: [String: Any] = [
            "stream_id": streamId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        socket?.emit("subscribe", payload)
        print("📺 [TipioWS] Subscribed to stream: \(streamId)")
    }
    
    /// Unsubscribe from events for a specific livestream
    public func unsubscribeFromStream(_ streamId: Int) {
        guard isConnected else {
            print("❌ [TipioWS] Cannot unsubscribe - not connected")
            return
        }
        
        let payload: [String: Any] = [
            "stream_id": streamId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        socket?.emit("unsubscribe", payload)
        print("📺 [TipioWS] Unsubscribed from stream: \(streamId)")
    }
    
    // MARK: - Private Methods
    
    // Build Socket.IO config: origin URL, path (ending in /socket.io), and optional namespace
    private func buildSocketIOConfig(from base: String) -> (URL, String, String?)? {
        var baseString = base
        baseString = baseString.replacingOccurrences(of: "wss://", with: "https://")
        baseString = baseString.replacingOccurrences(of: "ws://", with: "http://")
        guard var components = URLComponents(string: baseString) else { return nil }
        
        let path = components.path.isEmpty ? "/socket.io" : components.path + "/socket.io"
        components.path = ""
        guard let originURL = components.url else { return nil }
        
        // No usar namespace por defecto; backends suelen usar el default "/"
        let namespace: String? = nil
        return (originURL, path, namespace)
    }
    
    private func receiveMessage() { /* handled by Socket.IO listeners */ }
    
    private func handleReceivedMessage(_ result: Result<URLSessionWebSocketTask.Message, Error>) { /* unused in Socket.IO */ }
    
    private func handleTextMessage(_ text: String) {
        print("📨 [TipioWS] Received text: \(text)")
        
        // For Socket.IO, textual messages are uncommon here; leave best-effort decoding
        
        // Try to decode as TipioEvent
        guard let data = text.data(using: .utf8) else {
            print("❌ [TipioWS] Failed to convert text to data")
            return
        }
        
        handleDataMessage(data)
    }
    
    private func handleDataMessage(_ data: Data) {
        do {
            let event = try JSONDecoder().decode(TipioEvent.self, from: data)
            print("📡 [TipioWS] Received event: \(event.type.rawValue) for stream \(event.streamId)")
            eventSubject.send(event)
        } catch {
            // Try alternate schema for live stream lifecycle events
            do {
                struct RawLiveEvent: Codable {
                    let event: String
                    let stream: LiveStream
                }
                let raw = try JSONDecoder().decode(RawLiveEvent.self, from: data)
                switch raw.event {
                case "live-event-started":
                    liveEventSubject.send(.started(raw.stream))
                    print("📺 [TipioWS] Live event started: \(raw.stream.id)")
                case "live-event-ended":
                    liveEventSubject.send(.ended(raw.stream))
                    print("⏹️ [TipioWS] Live event ended: \(raw.stream.id)")
                default:
                    print("⚠️ [TipioWS] Unknown live event: \(raw.event)")
                }
            } catch {
                print("❌ [TipioWS] Failed to decode message: \(error)")
            }
        }
    }
    
    private func sendMessage(_ message: [String: Any]) { /* replaced by socket.emit */ }
    
    private func sendPong() { /* managed by Socket.IO internals */ }
    
    private func startHeartbeat() { /* unnecessary for Socket.IO */ }
    
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
    
    private func sendHeartbeat() { /* unnecessary for Socket.IO */ }
    
    private func handleConnectionError(_ error: Error) {
        print("❌ [TipioWS] Connection error: \(error)")
        updateConnectionStatus(.error(error.localizedDescription))
        
        stopHeartbeat()
        
        // Attempt reconnection if not at max attempts
        if reconnectAttempts < maxReconnectAttempts {
            scheduleReconnect()
        } else {
            print("❌ [TipioWS] Max reconnect attempts reached")
            updateConnectionStatus(.disconnected)
        }
    }
    
    private func scheduleReconnect() {
        stopReconnectTimer()
        
        updateConnectionStatus(.reconnecting)
        reconnectAttempts += 1
        
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0) // Exponential backoff, max 30s
        
        print("🔄 [TipioWS] Scheduling reconnect in \(delay)s (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")
        
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                // Socket.IO manager auto-reconnects; ensure connect() is called if not connected
                if self?.connectionStatus != .connected {
                    self?.connect()
                }
            }
        }
    }
    
    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
    private func resetReconnectAttempts() {
        reconnectAttempts = 0
        stopReconnectTimer()
    }
    
    private func updateConnectionStatus(_ status: ConnectionStatus) {
        connectionStatus = status
        isConnected = (status == .connected)
        connectionSubject.send(status)
        
        print("🔌 [TipioWS] Connection status: \(status.displayName)")
    }
    
    deinit {
        Task { @MainActor in
            self.cleanup()
        }
        print("🔌 [TipioWS] WebSocket client deinitialized")
    }
    
    /// Clean up all resources and timers
    private func cleanup() {
        stopHeartbeat()
        stopReconnectTimer()
        
        // Remove all event listeners
        socket?.removeAllHandlers()
        socket?.disconnect()
        socket = nil
        socketManager = nil
        
        // Cancel WebSocket task
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        // Reset connection state
        updateConnectionStatus(.disconnected)
        reconnectAttempts = 0
        
        print("🧹 [TipioWS] Cleanup completed")
    }
}

// MARK: - Error Types

public enum TipioWebSocketError: LocalizedError {
    case invalidURL
    case connectionFailed
    case authenticationFailed
    case messageDecodingFailed
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .connectionFailed:
            return "WebSocket connection failed"
        case .authenticationFailed:
            return "WebSocket authentication failed"
        case .messageDecodingFailed:
            return "Failed to decode WebSocket message"
        }
    }
}

// MARK: - Socket.IO Event Handling

extension TipioWebSocketClient {
    fileprivate func registerDomainEventHandlers(on client: SocketIOClient) {
        client.on("live-event-started") { [weak self] data, _ in
            print("🟢 [TipioWS] Evento recibido: live-event-started, payload: \(data)")
            guard let self = self, let first = data.first else {
                print("⚠️ [TipioWS] No se recibió payload en live-event-started")
                return
            }
            // Si el payload viene envuelto en un diccionario con clave "payload"
            if let dict = first as? [String: Any], let payload = dict["payload"] {
                if let tipio = self.decode(TipioLiveStream.self, from: payload) {
                    let stream = tipio.toLiveStream()
                    self.liveEventSubject.send(.started(stream))
                    print("📺 [TipioWS] Live event started: \(stream.id)")
                } else {
                    print("❌ [TipioWS] No se pudo decodificar TipioLiveStream en live-event-started. Payload: \(payload)")
                }
            } else if let tipio = self.decode(TipioLiveStream.self, from: first) {
                let stream = tipio.toLiveStream()
                self.liveEventSubject.send(.started(stream))
                print("📺 [TipioWS] Live event started: \(stream.id)")
            } else {
                print("❌ [TipioWS] No se pudo decodificar TipioLiveStream en live-event-started. Payload: \(first)")
            }
        }      
        client.on("live-event-ended") { [weak self] data, _ in
            print("🟢 [TipioWS] Evento recibido: live-event-ended, payload: \(data)")
            guard let self = self, let first = data.first else {
                print("⚠️ [TipioWS] No se recibió payload en live-event-ended")
                return
            }
            // Si el payload viene envuelto en un diccionario con clave "payload"
            if let dict = first as? [String: Any], let payload = dict["payload"] {
                if let tipio = self.decode(TipioLiveStream.self, from: payload) {
                    let stream = tipio.toLiveStream()
                    self.liveEventSubject.send(.ended(stream))
                    print("⏹️ [TipioWS] Live event ended: \(stream.id)")
                } else {
                    print("❌ [TipioWS] No se pudo decodificar TipioLiveStream en live-event-ended. Payload: \(payload)")
                }
            } else if let tipio = self.decode(TipioLiveStream.self, from: first) {
                let stream = tipio.toLiveStream()
                self.liveEventSubject.send(.ended(stream))
                print("⏹️ [TipioWS] Live event ended: \(stream.id)")
            } else {
                print("❌ [TipioWS] No se pudo decodificar TipioLiveStream en live-event-ended. Payload: \(first)")
            }
        }
        client.on("tipio-event") { [weak self] data, _ in
            guard let self = self, let first = data.first else { return }
            if let event = self.decode(TipioEvent.self, from: first) {
                self.eventSubject.send(event)
                print("📡 [TipioWS] Received event: \(event.type.rawValue) for stream \(event.streamId)")
            }
        }
        ["stream-status", "chat-message", "viewer-count", "product-highlight", "component"].forEach { name in
            client.on(name) { [weak self] data, _ in
                guard let self = self, let first = data.first else { return }
                if let event = self.decode(TipioEvent.self, from: first) {
                    self.eventSubject.send(event)
                }
            }
        }

        // HEART evento del microservicio de hearts
        client.on("HEART") { [weak self] data, _ in
            guard let self = self, let first = data.first else { return }
            print("🟢 [TipioWS] Evento recibido: HEART")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("reachu.heart.received"), object: nil)
            }
        }

        client.on("CHAT") { [weak self] data, _ in
            guard let self = self, let first = data.first else { return }
            print("💬 [TipioWS] Evento recibido: CHAT")

            // Configurar decoder
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Helper local para decodificar Any -> Decodable
            func decode<T: Decodable>(_ type: T.Type, from any: Any) -> T? {
                guard let dict = any as? [String: Any],
                    let jsonData = try? JSONSerialization.data(withJSONObject: dict) else {
                    return nil
                }
                return try? decoder.decode(type, from: jsonData)
            }

            // Caso 1: payload dentro del diccionario
            if let dict = first as? [String: Any], let payload = dict["payload"] {
                 if let chatMessage = decode(TipioChatMessage.self, from: payload) {
                    print("🔍 [TipioWS] chatMessage is pinned \(chatMessage.pinned) message \(chatMessage.text)")
                     let event = TipioEvent(
                         type: .chatMessage,
                         streamId: 0, // can be updated based on context
                         timestamp: Date(),
                         data: .chatMessage(chatMessage.toTipioChatMessageData())
                     )
                     self.eventSubject.send(event)
                     print("📡 [TipioWS] Chat message received: \(chatMessage.text)")
                 } else {
                     print("❌ [TipioWS] * No se pudo decodificar TipioChatMessage en CHAT. Payload: \(payload)")
                 }
             // Caso 2: el mensaje viene directo sin wrapper
             } else {
                print("❌ [TipioWS] ** No se pudo decodificar TipioChatMessage en CHAT. Payload: \(first)")
            }
        }
   
        // DELETE-PINNED-MESSAGE evento para eliminar mensajes fijados
        client.on("DELETE-PINNED-MESSAGE") { [weak self] data, _ in
            guard let self = self, let first = data.first else { return }
            print("🗑️ [TipioWS] Evento recibido: DELETE-PINNED-MESSAGE")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Extract payload from wrapper, similar to other events
            if let dict = first as? [String: Any],
            let payload = dict["payload"],
            let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
            let deleteData = try? decoder.decode(TipioDeletePinnedMessageData.self, from: jsonData) {

                let event = TipioEvent(
                    type: .deletePinnedMessage,
                    streamId: 0,
                    timestamp: Date(),
                    data: .deletePinnedMessage(deleteData)
                )
                self.eventSubject.send(event)
                print("📡 [TipioWS] Delete pinned message received: \(deleteData.message.clientId)")

            } else {
                print("❌ [TipioWS] No se pudo decodificar TipioDeletePinnedMessageData en DELETE-PINNED-MESSAGE. Payload: \(first)")
            }
        }
    }
        
    fileprivate func handleAnySocketEvent(_ event: SocketAnyEvent) {
        guard let items = event.items, !items.isEmpty, let payload = items.first else { return }
        // Intentar decodificar solo si parece contener claves relevantes
        if let dict = payload as? [String: Any] {
            let hasEventKey = dict["event"] != nil || dict["type"] != nil
            let hasDataKey = dict["data"] != nil || dict["stream"] != nil
            if hasEventKey || hasDataKey {
                if let data = try? JSONSerialization.data(withJSONObject: dict, options: []) {
                    handleDataMessage(data)
                }
            }
        } else if let str = payload as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                if let data = str.data(using: .utf8) {
                    handleDataMessage(data)
                }
            }
        }
        // Si no es relevante, ignoramos el evento
    }
    
    fileprivate func decode<T: Decodable>(_ type: T.Type, from any: Any) -> T? {
        if let dict = any as? [String: Any], let data = try? JSONSerialization.data(withJSONObject: dict) {
            return try? JSONDecoder().decode(T.self, from: data)
        }
        if let str = any as? String, let data = str.data(using: .utf8) {
            return try? JSONDecoder().decode(T.self, from: data)
        }
        if let data = any as? Data {
            return try? JSONDecoder().decode(T.self, from: data)
        }
        return nil
    }
}
