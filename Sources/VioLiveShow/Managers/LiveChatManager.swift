import Foundation
import SwiftUI
import Combine
import VioCore

/// Manager for live chat functionality with demo data simulation
@MainActor
public class LiveChatManager: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = LiveChatManager()
    
    // MARK: - Published Properties
    @Published public private(set) var messages: [LiveChatMessage] = []
    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var currentUser: LiveChatUser
    @Published public var userName: String = ""
    @Published public var hasUserName: Bool = false
    @Published public private(set) var pinnedMessage: LiveChatMessage?
    
    // Chat context
    @Published public private(set) var channel: String?
    @Published public private(set) var role: String = "USER"
    
    // MARK: - Private Properties
    private var messageTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    private init() {
        // Create current user (demo)
        self.currentUser = LiveChatUser(
            id: "current-user",
            username: "you",
            avatarUrl: nil,
            isVerified: false,
            isModerator: false
        )
        
        // setupDemoData()
        // startMessageSimulation()
    }
    
    // MARK: - Public Methods
    
    /// Set user name for chat
    public func setUserName(_ name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        self.userName = trimmedName
        self.hasUserName = true
        
        // Update current user with new name
        self.currentUser = LiveChatUser(
            id: currentUser.id,
            username: trimmedName,
            avatarUrl: currentUser.avatarUrl,
            isVerified: currentUser.isVerified,
            isModerator: currentUser.isModerator
        )
        
        print("👤 [Chat] User name set: \(trimmedName)")
    }
    
    /// Clear user name
    public func clearUserName() {
        self.userName = ""
        self.hasUserName = false
        print("👤 [Chat] User name cleared")
    }
    
    /// Configure chat context
    public func configure(channel: String, role: String = "USER") {
        self.channel = channel
        self.role = role
    }
    
    /// Send a message to the chat (Interactions API with pending queue)
    public func sendMessage(_ text: String, pinned: Bool = false, father: [String: Any]? = nil) {
        guard hasUserName else {
            print("❌ [Chat] Cannot send message without user name")
            return
        }
        guard let channel = self.channel else {
            print("⚠️ [Chat] Channel is not configured. Use configure(channel:) before sending.")
            let fallback = LiveChatMessage(
                user: currentUser,
                message: text,
                timestamp: Date(),
                isStreamerMessage: false,
                isPinned: pinned,
                reactions: []
            )
            messages.append(fallback)
            return
        }
        
        let now = Date()
        let clientId = getOrCreateClientId()
        let connectionId = "chat-\(channel)"
        let uuid = UUID().uuidString
        
        var dataBlock: [String: Any] = [
            "type": "chatMessage",
            "text": text,
            "user": userName,
            "clientId": clientId,
            "role": role,
            "pinned": pinned,
            "userTime": iso8601(now),
            "father": father as Any,
            "replies": []
        ]
        if father == nil { dataBlock["father"] = NSNull() }
        
        let chatBlock: [String: Any] = [
            "clientId": clientId,
            "connectionId": connectionId,
            "data": dataBlock,
            "encoding": NSNull(),
            "messageid": iso8601(now),
            "name": userName
        ]
        
        let payload: [String: Any] = [
            "type": "chatMessage",
            "text": text,
            "user": userName,
            "clientId": clientId,
            "role": role,
            "pinned": pinned,
            "userTime": iso8601(now),
            "father": father as Any,
            "replies": [],
            "servicesData": [
                "liveStreamId": channel,
                "uuid": uuid,
                "chat": chatBlock
            ]
        ]
        
        // Optimistic UI
        // let optimistic = LiveChatMessage(
        //     user: currentUser,
        //     message: text,
        //     timestamp: now,
        //     isStreamerMessage: false,
        //     isPinned: pinned,
        //     reactions: []
        // )
        // messages.append(optimistic)
        
        Task {
            let ok = await postChatMessage(payload: payload)
            if ok {
                await self.resendPendingMessagesIfAny()
            } else {
                self.addPendingMessage(payload, for: channel)
            }
        }
    }
    
    /// Connect to chat (simulation)
    public func connect() {
        isConnected = true
        print("🔌 [Chat] Connected to live chat")
    }
    
    /// Disconnect from chat
    public func disconnect() {
        isConnected = false
        messageTimer?.invalidate()
        messageTimer = nil
        print("🔌 [Chat] Disconnected from live chat")
    }
    
    /// Clear all messages
    public func clearMessages() {
        messages.removeAll()
        print("🗑️ [Chat] Messages cleared")
    }
    
    /// Load chat messages from API
    public func loadChatMessages(channel: String, migrated: Bool = false) async {
        let baseUrl = "https://stg-dev-microservices.tipioapp.com/stg-interactions";
        
        var urlString = "\(baseUrl)/chat/by-channel/chat-\(channel)"
        if migrated {
            urlString += "?migratedChats=true"
        }

        print(migrated ? "🔄 [Chat] Loading migrated messages for channel \(channel)" : "🔄 [Chat] Loading messages for channel \(channel)")
        print("🔗 [Chat] URL: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("❌ [Chat] Invalid URL: \(urlString)")
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [Chat] Invalid response")
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                print("❌ [Chat] API error: \(httpResponse.statusCode)")
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            // Parse the response data
            let chatMessages = try decoder.decode([TipioChatMessage].self, from: data)
            
            // Convert to LiveChatMessage format
            let liveChatMessages = chatMessages.map { $0.toLiveChatMessage() }

            if let lastPinnedMessage = liveChatMessages.last(where: { $0.isPinned }) {
                // Guardarlo en tu variable de pinnedMessage
                pinnedMessage = lastPinnedMessage
                print("📌 [Chat] Pinned message updated: \(lastPinnedMessage.message)")
            } else {
                print("📌 [Chat] No pinned messages found")
            }
            
            let normalMessages = liveChatMessages.filter { !$0.isPinned }

            // Asignar solo los normales a self.messages
            await MainActor.run {
                self.messages = normalMessages.sorted { $0.timestamp < $1.timestamp }
                print("📥 [Chat] Loaded \(self.messages.count) normal messages from API")
            }
            
        } catch {
            print("❌ [Chat] Failed to load messages: \(error)")
        }
    }
    
    /// Add a message programmatically (for testing)
    public func addMessage(_ message: LiveChatMessage) {
        messages.append(message)
    }
    
    /// Process incoming chat message from WebSocket
    public func processIncomingMessage(_ tipioMessage: TipioChatMessageData) {
        // Convert to LiveChatMessage
        let liveMessage = tipioMessage.toLiveChatMessage()
        
        // Enhanced duplicate detection
        if isDuplicateMessage(liveMessage) {
            print("⚠️ [Chat] Duplicate message ignored from \(liveMessage.user.username)")
            return
        }
        
        print("💬 [Chat] Added incoming message from \(liveMessage.user.username): \(liveMessage.message) \(liveMessage.isPinned)")
        
        // Handle pinned messages
        if liveMessage.isPinned {
            pinnedMessage = liveMessage
            print("📌 [Chat] Pinned message updated: \(liveMessage.message)")
        } else {
            messages.append(liveMessage)
            
            // Keep only last 100 messages for performance
            if messages.count > 100 {
                messages = Array(messages.suffix(100))
            }
        }
    }
    
    /// Enhanced duplicate message detection
    private func isDuplicateMessage(_ message: LiveChatMessage) -> Bool {
        // Check by user ID, timestamp, and message content for more accurate detection
        return messages.contains { existingMessage in
            return existingMessage.user.id == message.user.id &&
                   abs(existingMessage.timestamp.timeIntervalSince(message.timestamp)) < 1.0 && // Within 1 second
                   existingMessage.message == message.message
        }
    }
    
    /// Process delete pinned message event
    public func processDeletePinnedMessage(_ deleteData: TipioDeletePinnedMessageData) {
        // Check if the deleted message matches our current pinned message
        if let currentPinned = pinnedMessage,
           currentPinned.user.id == deleteData.message.clientId &&
           abs(currentPinned.timestamp.timeIntervalSince(deleteData.message.messageid)) < 1.0 {
            
            pinnedMessage = nil
            print("🗑️ [Chat] Pinned message removed: \(currentPinned.message)")
        }
    }
    
    // MARK: - Private Methods
    
    // private func setupDemoData() {
    //     let demoMessages = DemoChatData.initialMessages
    //     messages = demoMessages
        
    //     print("📝 [Chat] Loaded \(messages.count) demo messages")
    // }
    
    // private func startMessageSimulation() {
    //     guard messageTimer == nil else { return }
        
    //     // Simulate new messages every 8-15 seconds
    //     messageTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 8...15), repeats: true) { _ in
    //         Task { @MainActor in
    //             self.simulateIncomingMessage()
                
    //             // Schedule next message with random interval
    //             self.messageTimer?.invalidate()
    //             self.messageTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 8...15), repeats: true) { _ in
    //                 Task { @MainActor in
    //                     self.simulateIncomingMessage()
    //                 }
    //             }
    //         }
    //     }
        
    //     print("🤖 [Chat] Message simulation started")
    // }
    
    private func simulateIncomingMessage() {
        let randomMessage = DemoChatData.randomMessages.randomElement()!
        let randomUser = DemoChatData.demoUsers.randomElement()!
        
        let message = LiveChatMessage(
            user: randomUser,
            message: randomMessage,
            timestamp: Date(),
            isStreamerMessage: randomUser.username == "@livehost",
            isPinned: false,
            reactions: []
        )
        
        messages.append(message)
        
        // Keep only last 50 messages for performance
        if messages.count > 50 {
            messages = Array(messages.suffix(50))
        }
        
        print("💬 [Chat] Simulated message from \(randomUser.username): \(randomMessage)")
    }
    
    // MARK: - Sending Helpers (ported from ChatInput.js)
    private func postChatMessage(payload: [String: Any]) async -> Bool {
        let baseUrl = "https://stg-dev-microservices.tipioapp.com/stg-interactions"
        guard let url = URL(string: "\(baseUrl)/chat/send") else { return false }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                print("❌ [Chat] POST /chat/send failed")
                return false
            }
            return true
        } catch {
            print("❌ [Chat] POST /chat/send error: \(error)")
            return false
        }
    }
    
    private func getOrCreateClientId() -> String {
        let key = "pubnub_uuid"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }
    
    private func pendingKey(for channel: String) -> String {
        return "pendingMessages_\(channel)"
    }
    
    private func addPendingMessage(_ message: [String: Any], for channel: String) {
        let key = pendingKey(for: channel)
        var arr = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        arr.append(message)
        UserDefaults.standard.set(arr, forKey: key)
        print("⏳ [Chat] Stored pending message (count=\(arr.count)) for channel \(channel)")
    }
    
    private func getPendingMessages(for channel: String) -> [[String: Any]] {
        let key = pendingKey(for: channel)
        return (UserDefaults.standard.array(forKey: key) as? [[String: Any]]) ?? []
    }
    
    private func setPendingMessages(_ messages: [[String: Any]], for channel: String) {
        let key = pendingKey(for: channel)
        UserDefaults.standard.set(messages, forKey: key)
    }
    
    private func resendPendingMessagesIfAny() async {
        guard let channel = self.channel else { return }
        let pending = getPendingMessages(for: channel)
        guard !pending.isEmpty else { return }
        var remaining: [[String: Any]] = []
        for msg in pending {
            let ok = await postChatMessage(payload: msg)
            if !ok { remaining.append(msg) }
        }
        setPendingMessages(remaining, for: channel)
        print("🔁 [Chat] Resent pending messages. Remaining: \(remaining.count)")
    }
    
    private func iso8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        return f.string(from: date)
    }
    
    // private func simulateResponseMessage() {
    //     let responses = DemoChatData.responseMessages
    //     let randomResponse = responses.randomElement()!
    //     let responseUser = DemoChatData.demoUsers.randomElement()!
        
    //     let message = LiveChatMessage(
    //         user: responseUser,
    //         message: randomResponse,
    //         timestamp: Date(),
    //         isStreamerMessage: responseUser.username == "@livehost",
    //         isPinned: false,
    //         reactions: []
    //     )
        
    //     messages.append(message)
    //     print("💬 [Chat] Simulated response: \(randomResponse)")
    // }
    
    deinit {
        // Clean up timers and resources synchronously
        messageTimer?.invalidate()
        messageTimer = nil
        
        // Cancel all pending operations
        cancellables.removeAll()
        
        print("🧹 [Chat] LiveChatManager cleanup completed")
    }
    
    /// Clean up all resources and timers (MainActor context)
    private func cleanup() {
        messageTimer?.invalidate()
        messageTimer = nil
        
        // Cancel all pending operations
        cancellables.removeAll()
        
        // Clear messages to free memory
        messages.removeAll()
        pinnedMessage = nil
        
        print("🧹 [Chat] LiveChatManager cleanup completed")
    }
}

// MARK: - Demo Chat Data

public struct DemoChatData {
    
    static let demoUsers: [LiveChatUser] = [
        LiveChatUser(
            id: "user1",
            username: "@livehost",
            avatarUrl: "https://picsum.photos/50/50?random=1",
            isVerified: true,
            isModerator: true
        ),
        LiveChatUser(
            id: "user2", 
            username: "fashionlover23",
            avatarUrl: "https://picsum.photos/50/50?random=2",
            isVerified: false,
            isModerator: false
        ),
        LiveChatUser(
            id: "user3",
            username: "styleinspo",
            avatarUrl: "https://picsum.photos/50/50?random=3",
            isVerified: true,
            isModerator: false
        ),
        LiveChatUser(
            id: "user4",
            username: "shoppingqueen",
            avatarUrl: "https://picsum.photos/50/50?random=4",
            isVerified: false,
            isModerator: false
        ),
        LiveChatUser(
            id: "user5",
            username: "trendwatcher",
            avatarUrl: "https://picsum.photos/50/50?random=5",
            isVerified: true,
            isModerator: false
        ),
        LiveChatUser(
            id: "user6",
            username: "casual_chic",
            avatarUrl: "https://picsum.photos/50/50?random=6",
            isVerified: false,
            isModerator: false
        )
    ]
    
    static let initialMessages: [LiveChatMessage] = [
        LiveChatMessage(
            user: demoUsers[0],
            message: "Welcome to our live beauty show! 💄✨",
            timestamp: Date().addingTimeInterval(-300),
            isStreamerMessage: true
        ),
        LiveChatMessage(
            user: demoUsers[1],
            message: "Can you show it in black?",
            timestamp: Date().addingTimeInterval(-250)
        ),
        LiveChatMessage(
            user: demoUsers[2],
            message: "Just ordered! Can't wait ❤️",
            timestamp: Date().addingTimeInterval(-200)
        ),
        LiveChatMessage(
            user: demoUsers[3],
            message: "This would look great with jeans",
            timestamp: Date().addingTimeInterval(-150)
        ),
        LiveChatMessage(
            user: demoUsers[4],
            message: "So stylish! 👏",
            timestamp: Date().addingTimeInterval(-100)
        ),
        LiveChatMessage(
            user: demoUsers[5],
            message: "Adding to cart now!",
            timestamp: Date().addingTimeInterval(-50)
        )
    ]
    
    static let randomMessages: [String] = [
        "Love this! 😍",
        "Where can I buy this?",
        "What size would you recommend?",
        "This looks amazing! 🤩",
        "Perfect for summer!",
        "Already in my cart! 🛒",
        "Can you show the back?",
        "What's the material?",
        "Shipping to Europe?",
        "Is there a discount code?",
        "This color is gorgeous! 💕",
        "Just what I was looking for!",
        "How's the fit?",
        "Ordering right now! 🎉",
        "Can you model it?",
        "What other colors available?",
        "Price looks good! 💰",
        "Adding to wishlist ⭐",
        "Perfect timing! 🕐",
        "Looks premium quality 👌"
    ]
    
    static let responseMessages: [String] = [
        "Thanks for joining! 🙌",
        "Check the product details below! 👇",
        "Limited time offer! ⏰",
        "Great choice! 👍",
        "You'll love it! 💕",
        "Don't miss out! 🚀",
        "Perfect for any occasion! ✨",
        "High quality guaranteed! 🏆",
        "Ships worldwide! 🌍",
        "Use code LIVE20 for 20% off! 🎁"
    ]
}
