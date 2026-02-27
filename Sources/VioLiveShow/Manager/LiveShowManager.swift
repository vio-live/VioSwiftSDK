import Foundation
import SwiftUI
import Combine
import VioCore
import struct Foundation.Date

/// Global manager for LiveShow functionality (livestream UI, chat, hearts).
/// Tipio integration removed per CLEANUP_TIPIO — SDK keeps only Vio (engagement) + Commerce.
@MainActor
public class LiveShowManager: ObservableObject {
    
    public static let shared = LiveShowManager()
    
    @Published public private(set) var isLiveShowVisible: Bool = false
    @Published public private(set) var currentStream: LiveStream?
    @Published public private(set) var layout: LiveStreamLayout = .fullScreenOverlay
    @Published public private(set) var isMiniPlayerVisible: Bool = false
    @Published public private(set) var miniPlayerPosition: MiniPlayerPosition = .bottomRight
    @Published public private(set) var isIndicatorVisible: Bool = true
    @Published public private(set) var activeStreams: [LiveStream] = []
    
    @Published public private(set) var isConnectedToTipio: Bool = false
    @Published public private(set) var connectionStatus: String = "Disconnected"
    @Published public private(set) var currentViewerCount: Int = 0
    
    private var cancellables = Set<AnyCancellable>()
    private let configuration: LiveShowConfiguration
    private let heartApiBase: String = "https://stg-dev-microservices.tipioapp.com/stg-hearts"
    private let userDefaults = UserDefaults.standard
    private let userTrackingKey = "vio.userTrackingId"
    
    private init() {
        self.configuration = VioConfiguration.shared.liveShowConfiguration
    }
    
    public func updateCurrentStream(_ stream: LiveStream) {
        self.currentStream = stream
        LiveChatManager.shared.configure(channel: stream.id, role: "USER")
        Task { @MainActor in
            await LiveChatManager.shared.loadChatMessages(channel: stream.id, migrated: !stream.isLive)
        }
    }
    
    public func showLiveStream(_ stream: LiveStream, layout: LiveStreamLayout = .fullScreenOverlay) {
        self.currentStream = stream
        self.layout = layout
        self.isLiveShowVisible = true
        self.isMiniPlayerVisible = false
        LiveChatManager.shared.configure(channel: stream.id, role: "USER")
        Task { @MainActor in
            await LiveChatManager.shared.loadChatMessages(channel: stream.id, migrated: !stream.isLive)
        }
    }
    
    public func showLiveStream(id: String, layout: LiveStreamLayout = .fullScreenOverlay) {
        guard let stream = activeStreams.first(where: { $0.id == id }) else { return }
        showLiveStream(stream, layout: layout)
    }
    
    public func hideLiveStream() {
        self.isLiveShowVisible = false
        self.isMiniPlayerVisible = false
        self.currentStream = nil
    }
    
    public func showMiniPlayer() {
        guard currentStream != nil else { return }
        self.isLiveShowVisible = false
        self.isMiniPlayerVisible = true
    }
    
    public func expandFromMiniPlayer() {
        guard currentStream != nil else { return }
        self.isMiniPlayerVisible = false
        self.isLiveShowVisible = true
    }
    
    public func toggleIndicator() { self.isIndicatorVisible.toggle() }
    public func hideIndicator() { self.isIndicatorVisible = false }
    public func showIndicator() { self.isIndicatorVisible = true }
    
    public func addProductToCart(_ liveProduct: LiveProduct, cartManager: LiveShowCartManaging) {
        let product = liveProduct.asProduct
        Task { await cartManager.addProduct(product, quantity: 1) }
    }
    
    public func quickBuyProduct(_ liveProduct: LiveProduct, cartManager: LiveShowCartManaging) {
        addProductToCart(liveProduct, cartManager: cartManager)
        cartManager.showCheckout()
    }
    
    public var hasActiveLiveStreams: Bool { !activeStreams.filter { $0.isLive }.isEmpty }
    public var totalViewerCount: Int { activeStreams.reduce(0) { $0 + $1.viewerCount } }
    public var isWatchingLiveStream: Bool { isLiveShowVisible || isMiniPlayerVisible }
    
    // MARK: - Tipio (no-op stubs — removed per CLEANUP_TIPIO)
    
    public func connectToTipio() {}
    public func disconnectFromTipio() {}
    public func fetchTipioLiveStream(id: Int) async {}
    public func fetchActiveTipioStreams() async {}
    public func startTipioLiveStream(id: Int) async {}
    public func stopTipioLiveStream(id: Int) async {}
    
    // MARK: - Hearts
    
    public var userTrackingId: String {
        if let existing = userDefaults.string(forKey: userTrackingKey), !existing.isEmpty {
            return existing
        }
        let generated = "ios-" + UUID().uuidString
        userDefaults.set(generated, forKey: userTrackingKey)
        return generated
    }
    
    public func sendHeartForCurrentStream(isVideoLive: Bool) {
        guard let current = currentStream, let liveStreamId = current.liveStreamId else {
            return
        }
        let clientId = userTrackingId
        let emojiChannel = "emojiChannel-\(liveStreamId)"
        let hasHeartedKey = "vio.hasHearted.\(liveStreamId)"
        let hasHeartedBefore = userDefaults.bool(forKey: hasHeartedKey)
        
        var urlString: String
        if isVideoLive {
            urlString = hasHeartedBefore
                ? "\(heartApiBase)/heart/socket-sdk/\(liveStreamId)"
                : "\(heartApiBase)/heart/livestream/\(liveStreamId)?origin=sdk"
        } else {
            urlString = "\(heartApiBase)/heart/livestream/\(liveStreamId)/after-show?origin=sdk"
        }
        
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["channel": emojiChannel, "clientId": clientId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), !hasHeartedBefore {
                self?.userDefaults.set(true, forKey: hasHeartedKey)
            }
        }.resume()
    }
    
    // MARK: - Demo / Simulate
    
    public func simulateNewChatMessage() {
        guard var stream = currentStream else { return }
        let newMessage = LiveChatMessage(
            user: LiveChatUser(id: "user_new", username: "live_viewer"),
            message: ["Amazing!", "Love it!", "Want this! 😍"].randomElement() ?? "Great!",
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
            chatMessages: [newMessage] + stream.chatMessages.prefix(20).map { $0 },
            liveStreamId: stream.liveStreamId
        )
        self.currentStream = stream
        if let index = activeStreams.firstIndex(where: { $0.id == stream.id }) {
            activeStreams[index] = stream
        }
    }
}
