import Foundation
import SwiftUI
import Combine
import VioCore
import struct Foundation.Date

// LiveShowCartManaging protocol is now in VioCore, so no additional import needed

// VioTesting import removed - using hardcoded demo data instead

/// Global manager for LiveShow functionality with Tipio.no integration
@MainActor
public class LiveShowManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = LiveShowManager()
    
    // MARK: - Published Properties
    @Published public private(set) var isLiveShowVisible: Bool = false
    @Published public private(set) var currentStream: LiveStream?
    @Published public private(set) var layout: LiveStreamLayout = .fullScreenOverlay
    @Published public private(set) var isMiniPlayerVisible: Bool = false
    @Published public private(set) var miniPlayerPosition: MiniPlayerPosition = .bottomRight
    @Published public private(set) var isIndicatorVisible: Bool = true
    @Published public private(set) var activeStreams: [LiveStream] = []
    
    // Tipio integration
    @Published public private(set) var isConnectedToTipio: Bool = false
    @Published public private(set) var connectionStatus: String = "Disconnected"
    @Published public private(set) var currentViewerCount: Int = 0
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let configuration: LiveShowConfiguration
    private let heartApiBase: String = "https://stg-dev-microservices.tipioapp.com/stg-hearts"
    private let userDefaults = UserDefaults.standard
    private let userTrackingKey = "reachu.userTrackingId"
    private var tipioIdToLiveStreamId: [Int: String] = [:] // maps Tipio id -> Tipio.liveStreamId (Vimeo event)
    
    // Tipio clients
    private lazy var tipioApiClient = TipioApiClient()
    private lazy var tipioWebSocketClient = TipioWebSocketClient(
        baseUrl: "https://stg-dev-microservices.tipioapp.com/stg-stream"
    )
    
    // MARK: - Initialization
    private init() {
        self.configuration = VioConfiguration.shared.liveShowConfiguration
        setupTipioIntegration()
        //setupDemoData()
        Task {
            await fetchActiveTipioStreams()        
        }
    }
    
    // MARK: - Public Methods

    public func updateCurrentStream(_ stream: LiveStream) {
        self.currentStream = stream
        // Configure chat channel using liveStreamId (mapped as stream.id)
        LiveChatManager.shared.configure(channel: stream.id, role: "USER")
        // Load chat history; consider migrated when not live
        Task { @MainActor in
            await LiveChatManager.shared.loadChatMessages(channel: stream.id, migrated: !stream.isLive)
        }
    }
    
    /// Show live stream with specified layout
    public func showLiveStream(_ stream: LiveStream, layout: LiveStreamLayout = .fullScreenOverlay) {
        self.currentStream = stream
        self.layout = layout
        self.isLiveShowVisible = true
        self.isMiniPlayerVisible = false
        // Configure chat channel on show
        LiveChatManager.shared.configure(channel: stream.id, role: "USER")
        Task { @MainActor in
            await LiveChatManager.shared.loadChatMessages(channel: stream.id, migrated: !stream.isLive)
        }
    }
    
    /// Show live stream by ID
    public func showLiveStream(id: String, layout: LiveStreamLayout = .fullScreenOverlay) {
        guard let stream = activeStreams.first(where: { $0.id == id }) else { return }
        showLiveStream(stream, layout: layout)
    }
    
    /// Hide live stream completely
    public func hideLiveStream() {
        self.isLiveShowVisible = false
        self.isMiniPlayerVisible = false
        self.currentStream = nil
    }
    
    /// Convert to mini player
    public func showMiniPlayer() {
        guard currentStream != nil else { return }
        self.isLiveShowVisible = false
        self.isMiniPlayerVisible = true
    }
    
    /// Expand from mini player
    public func expandFromMiniPlayer() {
        guard currentStream != nil else { return }
        self.isMiniPlayerVisible = false
        self.isLiveShowVisible = true
    }
    
    /// Toggle indicator visibility
    public func toggleIndicator() {
        self.isIndicatorVisible.toggle()
    }
    
    /// Hide indicator
    public func hideIndicator() {
        self.isIndicatorVisible = false
    }
    
    /// Show indicator
    public func showIndicator() {
        self.isIndicatorVisible = true
    }
    
    /// Add product to cart from live stream
    /// Note: This requires `CartManager` to be provided by the host app (no UI dependencies here)
    public func addProductToCart(_ liveProduct: LiveProduct, cartManager: LiveShowCartManaging) {
        let product = liveProduct.asProduct
        Task {
            await cartManager.addProduct(product, quantity: 1)
        }
    }
    
    /// Quick buy product
    public func quickBuyProduct(_ liveProduct: LiveProduct, cartManager: LiveShowCartManaging) {
        addProductToCart(liveProduct, cartManager: cartManager)
        // Could trigger immediate checkout
        cartManager.showCheckout()
    }
    
    // MARK: - Computed Properties
    
    /// Check if there are active live streams
    public var hasActiveLiveStreams: Bool {
        !activeStreams.filter { $0.isLive }.isEmpty
    }
    
    /// Get total viewer count across all streams
    public var totalViewerCount: Int {
        activeStreams.reduce(0) { $0 + $1.viewerCount }
    }
    
    /// Check if any live stream is currently being watched
    public var isWatchingLiveStream: Bool {
        isLiveShowVisible || isMiniPlayerVisible
    }
    
    // MARK: - Tipio Integration Methods
    
    /// Connect to Tipio services
    public func connectToTipio() {
        print("🔌 [LiveShow] Connecting to Tipio...")
        tipioWebSocketClient.connect()
    }
    
    /// Disconnect from Tipio services
    public func disconnectFromTipio() {
        print("🔌 [LiveShow] Disconnecting from Tipio...")
        tipioWebSocketClient.disconnect()
    }
    
    /// Fetch livestream from Tipio by ID
    public func fetchTipioLiveStream(id: Int) async {
        do {
            print("📡 [LiveShow] Fetching Tipio livestream: \(id)")
            let tipioStream = try await tipioApiClient.getLiveStream(id: id)
            // Save mapping Tipio.id -> Tipio.liveStreamId
            tipioIdToLiveStreamId[tipioStream.id] = tipioStream.liveStreamId
            
            // Convert to Vio LiveStream
            let liveStream = tipioStream.toLiveStream()
            
            // Update active streams
            if let index = activeStreams.firstIndex(where: { $0.id == liveStream.id }) {
                activeStreams[index] = liveStream
            } else {
                activeStreams.append(liveStream)
            }
            
            print("✅ [LiveShow] Successfully fetched and converted Tipio stream: \(tipioStream.title)")
            
            // Subscribe to real-time events for this stream
            tipioWebSocketClient.subscribeToStream(id)
            
        } catch {
            print("❌ [LiveShow] Failed to fetch Tipio livestream: \(error)")
        }
    }

    /// Fetch all active livestreams from Tipio
    public func fetchActiveTipioStreams() async {
        do {
            print("📡 [LiveShow] Fetching active Tipio livestreams")
            let tipioStreams = try await tipioApiClient.getActiveLiveStreams()
            // Save mappings for all
            tipioStreams.forEach { tipioIdToLiveStreamId[$0.id] = $0.liveStreamId }
            
            // Convert all to Vio LiveStreams
            let liveStreams = tipioStreams.map { $0.toLiveStream() }
            
            // Update active streams
            activeStreams = liveStreams
            
            print("✅ [LiveShow] Successfully fetched \(liveStreams.count) active streams from Tipio")
            
            // Subscribe to real-time events for all active streams
            for tipioStream in tipioStreams {
                tipioWebSocketClient.subscribeToStream(tipioStream.id)
            }
            
        } catch {
            print("❌ [LiveShow] Failed to fetch active Tipio livestreams: \(error)")
            // setupDemoData()
        }
    }

    // MARK: - Hearts / Likes

    /// Identificador de tracking del usuario. Persistente.
    public var userTrackingId: String {
        if let existing = userDefaults.string(forKey: userTrackingKey), !existing.isEmpty {
            return existing
        }
        let generated = "ios-" + UUID().uuidString
        userDefaults.set(generated, forKey: userTrackingKey)
        return generated
    }

    /// Sends a like (HEART) for the current stream.
    /// - parameter isVideoLive: whether the video is live (controls `after-show`).
    public func sendHeartForCurrentStream(isVideoLive: Bool) {
        guard let current = currentStream, let tipioIntId = Int(current.id) else {
            print("❌ [LiveShow] sendHeart: no current stream or invalid id")
            return
        }
        guard let liveStreamId = tipioIdToLiveStreamId[tipioIntId] else {
            print("❌ [LiveShow] sendHeart: missing Tipio.liveStreamId mapping for stream id \(tipioIntId)")
            return
        }

        let clientId = userTrackingId
        let emojiChannel = "emojiChannel-\(liveStreamId)"
        let hasHeartedKey = "reachu.hasHearted.\(liveStreamId)"
        let hasHeartedBefore = userDefaults.bool(forKey: hasHeartedKey)

        var urlString: String

        if isVideoLive {
            if hasHeartedBefore {
                urlString = "\(heartApiBase)/heart/socket-sdk/\(liveStreamId)"
            } else {
                urlString = "\(heartApiBase)/heart/livestream/\(liveStreamId)?origin=sdk"
            }
        } else {
            urlString = "\(heartApiBase)/heart/livestream/\(liveStreamId)/after-show?origin=sdk"
        }

        print("🚀 [LiveShow] Sending HEART to \(urlString)")

        guard let url = URL(string: urlString) else {
            print("❌ [LiveShow] sendHeart: invalid URL \(urlString)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "channel": emojiChannel,
            "clientId": clientId
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ [LiveShow] HEART request error: \(error.localizedDescription)")
                return
            }
            if let http = response as? HTTPURLResponse {
                print("❤️ [LiveShow] HEART \(hasHeartedBefore ? "socket-sdk" : "livestream") status=\(http.statusCode)")
                if http.statusCode >= 200 && http.statusCode < 300 {
                    // Marcar como ya enviado al menos una vez
                    if hasHeartedBefore == false {
                        self?.userDefaults.set(true, forKey: hasHeartedKey)
                    }
                }
            }
        }
        task.resume()
    }
    
    /// Start a livestream via Tipio
    public func startTipioLiveStream(id: Int) async {
        do {
            print("🚀 [LiveShow] Starting Tipio livestream: \(id)")
            let status = try await tipioApiClient.startLiveStream(id: id)
            print("✅ [LiveShow] Successfully started livestream: \(status)")
            
            // Refresh the stream data
            await fetchTipioLiveStream(id: id)
            
        } catch {
            print("❌ [LiveShow] Failed to start Tipio livestream: \(error)")
        }
    }
    
    /// Stop a livestream via Tipio
    public func stopTipioLiveStream(id: Int) async {
        do {
            print("⏹️ [LiveShow] Stopping Tipio livestream: \(id)")
            let status = try await tipioApiClient.stopLiveStream(id: id)
            print("✅ [LiveShow] Successfully stopped livestream: \(status)")
            
            // Refresh the stream data
            await fetchTipioLiveStream(id: id)
            
        } catch {
            print("❌ [LiveShow] Failed to stop Tipio livestream: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Setup Tipio integration and event handling
    private func setupTipioIntegration() {
        // Monitor WebSocket connection status
        tipioWebSocketClient.connectionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isConnectedToTipio = (status == .connected)
                self?.connectionStatus = status.displayName
            }
            .store(in: &cancellables)
        
        // Handle real-time events from Tipio
        tipioWebSocketClient.eventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleTipioEvent(event)
            }
            .store(in: &cancellables)

        // Handle lifecycle live events carrying full updated stream
        tipioWebSocketClient.liveEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] liveEvent in
                guard let self = self else { return }
                switch liveEvent {
                case .started(let stream):
                    // Update or insert stream and mark as live/current if matching
                    if let index = self.activeStreams.firstIndex(where: { $0.id == stream.id }) {
                        self.activeStreams[index] = stream
                    } else {
                        self.activeStreams.append(stream)
                    }
                    if self.currentStream?.id == stream.id {
                        self.currentStream = stream
                    }
                case .ended(let stream):
                    // Update stream state to not live; update current if matching
                    if let index = self.activeStreams.firstIndex(where: { $0.id == stream.id }) {
                        self.activeStreams[index] = stream
                    }
                    if self.currentStream?.id == stream.id {
                        self.currentStream = stream
                    }
                }
            }
            .store(in: &cancellables)

        // Ensure socket connection starts
        tipioWebSocketClient.connect()
        
        print("🔧 [LiveShow] Tipio integration setup completed")
    }
    
    /// Handle real-time events from Tipio WebSocket
    private func handleTipioEvent(_ event: TipioEvent) {
        print("📡 [LiveShow] Handling Tipio event: \(event.type.rawValue) for stream \(event.streamId)")
        
        switch event.data {
        case .streamStatus(let statusData):
            handleStreamStatusUpdate(streamId: event.streamId, status: statusData)
            
        case .chatMessage(let chatData):
            handleChatMessage(streamId: event.streamId, chatData: chatData)             
            
        case .viewerCount(let viewerData):
            handleViewerCountUpdate(streamId: event.streamId, viewerData: viewerData)
            
        case .productHighlight(let productData):
            handleProductHighlight(streamId: event.streamId, productData: productData)
            
        case .component(let componentData):
            handleComponentEvent(streamId: event.streamId, componentData: componentData)
            
        case .deletePinnedMessage(let deleteData):
            handleDeletePinnedMessage(streamId: event.streamId, deleteData: deleteData)
            
        @unknown default:
            print("⚠️ [LiveShow] Unknown TipioEvent data type: \(event.data)")
        }
    }

    
    /// Handle stream status updates
    private func handleStreamStatusUpdate(streamId: Int, status: TipioStreamStatusData) {
        guard let index = activeStreams.firstIndex(where: { $0.id == String(streamId) }) else {
            print("⚠️ [LiveShow] Stream not found for status update: \(streamId)")
            return
        }
        
        var updatedStream = activeStreams[index]
        
        // Update video URL if HLS is available
        if let hlsUrl = status.hlsUrl, !hlsUrl.isEmpty {
            updatedStream = LiveStream(
                id: updatedStream.id,
                title: updatedStream.title,
                description: updatedStream.description,
                streamer: updatedStream.streamer,
                videoUrl: hlsUrl,
                thumbnailUrl: updatedStream.thumbnailUrl,
                viewerCount: updatedStream.viewerCount,
                isLive: status.broadcasting,
                startTime: updatedStream.startTime,
                endTime: updatedStream.endTime,
                featuredProducts: updatedStream.featuredProducts,
                chatMessages: updatedStream.chatMessages
            )
            
            activeStreams[index] = updatedStream
            
            // Update current stream if it's the one being updated
            if currentStream?.id == updatedStream.id {
                currentStream = updatedStream
            }
            
            print("✅ [LiveShow] Updated stream status for: \(streamId)")
        }
    }
    
    /// Handle chat messages
    private func handleChatMessage(streamId: Int, chatData: TipioChatMessageData) {
        // Process message in LiveChatManager (with duplicate prevention)
        LiveChatManager.shared.processIncomingMessage(chatData)
        
        guard let index = activeStreams.firstIndex(where: { $0.id == String(streamId) }) else {
            return
        }
        
        let liveChatMessage = chatData.toLiveChatMessage()
        var updatedMessages = activeStreams[index].chatMessages
        updatedMessages.append(liveChatMessage)
        
        // Keep only last 100 messages for performance
        if updatedMessages.count > 100 {
            updatedMessages = Array(updatedMessages.suffix(100))
        }
        
        var updatedStream = activeStreams[index]
        updatedStream = LiveStream(
            id: updatedStream.id,
            title: updatedStream.title,
            description: updatedStream.description,
            streamer: updatedStream.streamer,
            videoUrl: updatedStream.videoUrl,
            thumbnailUrl: updatedStream.thumbnailUrl,
            viewerCount: updatedStream.viewerCount,
            isLive: updatedStream.isLive,
            startTime: updatedStream.startTime,
            endTime: updatedStream.endTime,
            featuredProducts: updatedStream.featuredProducts,
            chatMessages: updatedMessages
        )
        
        activeStreams[index] = updatedStream
        
        if currentStream?.id == updatedStream.id {
            currentStream = updatedStream
        }
        
        print("💬 [LiveShow] New chat message in stream \(streamId): \(chatData.message)")
    }
    
    /// Handle delete pinned message event
    private func handleDeletePinnedMessage(streamId: Int, deleteData: TipioDeletePinnedMessageData) {
        // Process delete pinned message in LiveChatManager
        LiveChatManager.shared.processDeletePinnedMessage(deleteData)
        print("🗑️ [LiveShow] Delete pinned message event for stream \(streamId)")
    }
    
    /// Handle viewer count updates
    private func handleViewerCountUpdate(streamId: Int, viewerData: TipioViewerCountData) {
        guard let index = activeStreams.firstIndex(where: { $0.id == String(streamId) }) else {
            return
        }
        
        var updatedStream = activeStreams[index]
        updatedStream = LiveStream(
            id: updatedStream.id,
            title: updatedStream.title,
            description: updatedStream.description,
            streamer: updatedStream.streamer,
            videoUrl: updatedStream.videoUrl,
            thumbnailUrl: updatedStream.thumbnailUrl,
            viewerCount: viewerData.count,
            isLive: updatedStream.isLive,
            startTime: updatedStream.startTime,
            endTime: updatedStream.endTime,
            featuredProducts: updatedStream.featuredProducts,
            chatMessages: updatedStream.chatMessages
        )
        
        activeStreams[index] = updatedStream
        
        if currentStream?.id == updatedStream.id {
            currentStream = updatedStream
            currentViewerCount = viewerData.count
        }
        
        print("👥 [LiveShow] Viewer count updated for stream \(streamId): \(viewerData.count)")
    }
    
    /// Handle product highlighting
    private func handleProductHighlight(streamId: Int, productData: TipioProductHighlightData) {
        print("🛍️ [LiveShow] Product highlighted in stream \(streamId): \(productData.productId)")
        // TODO: Implement product highlighting logic
        // This could trigger UI animations, overlays, etc.
    }
    
    /// Handle dynamic component events
    private func handleComponentEvent(streamId: Int, componentData: TipioComponentData) {
        print("🧩 [LiveShow] Component event in stream \(streamId): \(componentData.type) - Active: \(componentData.active)")
        // TODO: Implement dynamic component system
        // This could show/hide UI components, banners, countdowns, etc.
    }
    
    /// Setup demo data for development
    // private func setupDemoData() {
    //     // Use real Tipio demo data with working Vimeo URL
    //     let tipioStream = TipioLiveStream(
    //         id: 381,
    //         title: "test offline-asdasdasdad",
    //         liveStreamId: "5404404",
    //         hls: nil, // Start as null like in real Tipio
    //         player: "https://player.vimeo.com/video/1029631656", // Your working URL
    //         thumbnail: "https://storage.googleapis.com/tipio-images/1756737999235-012.png",
    //         broadcasting: true, // Set to true for demo
    //         date: ISO8601DateFormatter().date(from: "2025-09-03T16:45:00.000Z") ?? Date(),
    //         endDate: ISO8601DateFormatter().date(from: "2025-09-03T16:45:00.000Z") ?? Date(),
    //         streamDone: nil,
    //         videoId: "1029631656", // Use the working video ID
    //         videoUrl: nil
    //     )
        
    //     // Create demo streamers
    //     let streamer1 = LiveStreamer(
    //         id: "tipio-381",
    //         name: "Live Host",
    //         username: "@livehost",
    //         avatarUrl: "https://storage.googleapis.com/tipio-images/1756737999235-012.png",
    //         isVerified: true,
    //         followerCount: 1247
    //     )
        
    //     let streamer2 = LiveStreamer(
    //         id: "streamer2", 
    //         name: "Fashion Central",
    //         username: "@fashioncentral",
    //         avatarUrl: "https://picsum.photos/100/100?random=2",
    //         isVerified: true,
    //         followerCount: 85000
    //     )
        
    //     // Create hardcoded demo products for LiveShow
    //     let liveProducts = [
    //         LiveProduct(
    //             id: "live-101",
    //             title: "Vio Wireless Headphones",
    //             price: Price(amount: 199.99, currency_code: "USD"),
    //             originalPrice: Price(amount: 249.99, currency_code: "USD"),
    //             imageUrl: "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400&h=300&fit=crop&crop=center",
    //             isAvailable: true,
    //             stockCount: 50,
    //             discount: "20% OFF",
    //             specialOffer: "Special live price for viewers!",
    //             showUntil: Date().addingTimeInterval(600)
    //         ),
    //         LiveProduct(
    //             id: "live-102",
    //             title: "Vio Smart Watch Series 5",
    //             price: Price(amount: 349.99, currency_code: "USD"),
    //             originalPrice: nil,
    //             imageUrl: "https://images.unsplash.com/photo-1434493789847-2f02dc6ca35d?w=400&h=300&fit=crop&crop=center",
    //             isAvailable: true,
    //             stockCount: 30,
    //             specialOffer: "Latest smartwatch technology",
    //             showUntil: Date().addingTimeInterval(900)
    //         ),
    //         LiveProduct(
    //             id: "live-103",
    //             title: "Vio Minimalist Backpack",
    //             price: Price(amount: 89.99, currency_code: "USD"),
    //             originalPrice: Price(amount: 109.99, currency_code: "USD"),
    //             imageUrl: "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400&h=300&fit=crop&crop=center",
    //             isAvailable: true,
    //             stockCount: 15,
    //             discount: "18% OFF",
    //             specialOffer: "Perfect for daily use",
    //             showUntil: Date().addingTimeInterval(1200)
    //         )
    //     ]
        
    //     // Create demo chat messages
    //     // let chatMessages = createDemoChatMessages()
    //     let chatMessages = []
        
    //     // Create demo streams using Tipio data
    //     let stream1 = tipioStream.toLiveStream(
    //         streamer: streamer1,
    //         featuredProducts: Array(liveProducts), // Use converted mock products
    //         chatMessages: chatMessages
    //     )
        
    //     let stream2 = LiveStream(
    //         id: "stream-2",
    //         title: "Weekend Casual Styling",
    //         streamer: streamer2,
    //         videoUrl: "https://vimeo.com/1029631656", // Tu video de Vimeo
    //         thumbnailUrl: "https://i.vimeocdn.com/video/1029631656.jpg",
    //         viewerCount: 892,
    //         isLive: true,
    //         featuredProducts: Array(liveProducts.suffix(2)), // Use last 2 products
    //         chatMessages: chatMessages.dropFirst(5).map { $0 }
    //     )
        
    //     self.activeStreams = [stream1, stream2]
    // }
    
    /// Create demo chat messages
    // private func createDemoChatMessages() -> [LiveChatMessage] {
    //     let users = [
    //         LiveChatUser(id: "user1", username: "fashionlover23", isVerified: true),
    //         LiveChatUser(id: "user2", username: "styleinspo"),
    //         LiveChatUser(id: "user3", username: "shoppingqueen", isModerator: true),
    //         LiveChatUser(id: "user4", username: "trendwatcher"),
    //         LiveChatUser(id: "user5", username: "casual_chic"),
    //     ]
        
    //     let messages = [
    //         "Love this top! 😍",
    //         "Where can I get this?",
    //         "Looks amazing on you!",
    //         "How much is the shipping?",
    //         "Perfect for spring! 🌸",
    //         "Can you show it in black?",
    //         "Just ordered! Can't wait ❤️",
    //         "This would look great with jeans",
    //         "So stylish! 💫",
    //         "Adding to cart now!"
    //     ]
        
    //     return messages.enumerated().map { index, message in
    //         LiveChatMessage(
    //             user: users[index % users.count],
    //             message: message,
    //             timestamp: Date().addingTimeInterval(-TimeInterval(index * 30))
    //         )
    //     }
    // }
}

// MARK: - Mock Data Provider

extension LiveShowManager {
    
    /// Get featured live stream (for demo)
    public var featuredLiveStream: LiveStream? {
        activeStreams.first { $0.isLive }
    }
    
    /// Simulate receiving new chat message
    public func simulateNewChatMessage() {
        guard var stream = currentStream else { return }
        
        let newMessage = LiveChatMessage(
            user: LiveChatUser(id: "user_new", username: "live_viewer"),
            message: ["Amazing!", "Love it!", "Want this! 😍", "How much?", "Gorgeous! ✨"].randomElement() ?? "Great!",
            timestamp: Date()
        )
        
        stream = LiveStream(
            id: stream.id,
            title: stream.title,
            description: stream.description,
            streamer: stream.streamer,
            videoUrl: stream.videoUrl,
            thumbnailUrl: stream.thumbnailUrl,
            viewerCount: stream.viewerCount + Int.random(in: 1...5),
            isLive: stream.isLive,
            startTime: stream.startTime,
            endTime: stream.endTime,
            featuredProducts: stream.featuredProducts,
            chatMessages: [newMessage] + stream.chatMessages.prefix(20).map { $0 }
        )
        
        self.currentStream = stream
        
        // Update in active streams
        if let index = activeStreams.firstIndex(where: { $0.id == stream.id }) {
            activeStreams[index] = stream
        }
    }
}
