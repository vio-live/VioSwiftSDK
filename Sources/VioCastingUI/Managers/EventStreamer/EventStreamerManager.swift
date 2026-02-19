//
//  EventStreamerManager.swift
//  VioCastingUI
//
//  WebSocket manager for demo event stream (polls, products, contests).
//  URL: wss://event-streamer-angelo100.replit.app/ws/3
//

import Foundation
import Combine

/// Manager for WebSocket connection with demo event streamer
/// Delivers poll, product, and contest events to casting overlays
public class EventStreamerManager: NSObject, ObservableObject {
    @Published public var isConnected = false
    @Published public var currentPoll: PollEventData?
    @Published public var currentProduct: ProductEventData?
    @Published public var currentContest: ContestEventData?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    
    public override init() {
        super.init()
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    
    public func connect() {
        guard !isConnected else { return }
        
        let url = URL(string: "wss://event-streamer-angelo100.replit.app/ws/3")!
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        receiveMessage()
    }
    
    public func disconnect() {
        guard isConnected else { return }
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    private func receiveMessage() {
        guard isConnected, webSocketTask != nil else { return }
        
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                if self.isConnected {
                    self.receiveMessage()
                }
            case .failure:
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.webSocketTask = nil
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = json["type"] as? String
        else { return }
        
        do {
            switch eventType {
            case "product":
                let event = try JSONDecoder().decode(ProductEvent.self, from: data)
                handleProductEvent(event)
            case "poll":
                let event = try JSONDecoder().decode(PollEvent.self, from: data)
                handlePollEvent(event)
            case "contest":
                let event = try JSONDecoder().decode(ContestEvent.self, from: data)
                handleContestEvent(event)
            default:
                break
            }
        } catch {}
    }
    
    private func handleProductEvent(_ event: ProductEvent) {
        DispatchQueue.main.async {
            var productData = event.data
            if productData.campaignLogo == nil && event.campaignLogo != nil {
                productData.campaignLogo = event.campaignLogo
            }
            self.currentProduct = productData
        }
    }
    
    private func handlePollEvent(_ event: PollEvent) {
        DispatchQueue.main.async {
            var pollData = event.data
            if pollData.campaignLogo == nil && event.campaignLogo != nil {
                pollData.campaignLogo = event.campaignLogo
            }
            self.currentPoll = pollData
        }
    }
    
    private func handleContestEvent(_ event: ContestEvent) {
        DispatchQueue.main.async {
            var contestData = event.data
            if contestData.campaignLogo == nil && event.campaignLogo != nil {
                contestData.campaignLogo = event.campaignLogo
            }
            self.currentContest = contestData
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension EventStreamerManager: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}

// MARK: - Event Models

public struct ProductEvent: Codable {
    public let type: String
    public let data: ProductEventData
    public let campaignLogo: String?
    public let timestamp: Int64
}

public struct ProductEventData: Codable, Equatable {
    public let id: String
    public let productId: String
    public let name: String
    public let description: String
    public let price: String
    public let currency: String
    public let imageUrl: String
    public var campaignLogo: String?
}

public struct PollEvent: Codable {
    public let type: String
    public let data: PollEventData
    public let campaignLogo: String?
    public let timestamp: Int64
}

public struct PollEventData: Codable, Identifiable, Equatable {
    public let id: String
    public let question: String
    public let options: [PollOption]
    public let duration: Int
    public let imageUrl: String?
    public var campaignLogo: String?
}

public struct PollOption: Codable, Identifiable, Equatable {
    public let id = UUID()
    public let text: String
    public let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case text
        case avatarUrl
        case imageUrl
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        if let url = try container.decodeIfPresent(String.self, forKey: .avatarUrl) {
            avatarUrl = url
        } else {
            avatarUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
    }
    
    public init(text: String, avatarUrl: String?) {
        self.text = text
        self.avatarUrl = avatarUrl
    }
}

public struct ContestEvent: Codable {
    public let type: String
    public let data: ContestEventData
    public let campaignLogo: String?
    public let timestamp: Int64
}

public struct ContestEventData: Codable, Equatable {
    public let id: String
    public let name: String
    public let prize: String
    public let deadline: String
    public let maxParticipants: Int
    public var campaignLogo: String?
}
