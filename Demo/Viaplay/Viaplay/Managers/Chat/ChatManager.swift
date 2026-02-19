//
//  ChatManager.swift
//  Viaplay
//
//  Manager for chat messages and simulation
//  Integrated with UnifiedTimelineManager for video sync
//

import Foundation
import SwiftUI
import Combine
import VioCastingUI

@MainActor
class ChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var viewerCount: Int = 0
    
    private var timer: Timer?
    private var viewerTimer: Timer?
    private let maxMessages = 100
    
    // Timeline integration (optional - for sync with video)
    private weak var timeline: UnifiedTimelineManager?
    
    private let simulatedUsers: [(String, Color)] = [
        ("SportsFan23", .cyan),
        ("GoalKeeper", .green),
        ("MatchMaster", .orange),
        ("TeamCaptain", .red),
        ("ElClásico", .purple),
        ("FutbolLoco", .yellow),
        ("DefenderPro", .blue),
        ("StrikerKing", .pink),
        ("MidFielder", .mint),
        ("CoachView", .indigo),
        ("TacticsGuru", .teal),
        ("FanZone", .orange),
        ("LiveScore", .green),
        ("TeamSpirit", .purple),
        ("UltrasGroup", .red),
    ]
    
    private let simulatedMessages: [String] = [
        "Hvilket mål! 🔥",
        "For en redning!",
        "UTROLIG SPILL!!!",
        "Forsvaret sover...",
        "Dommeren er forferdelig",
        "KOM IGJEN! 💪",
        "Nydelig pasning",
        "Det burde vært straffe",
        "Keeperen er på et annet nivå",
        "SKYT!",
        "Hvorfor skjøt han ikke?",
        "Perfekt posisjonering",
        "Denne kampen er gal",
        "Vi trenger mål nå",
        "Taktikken fungerer",
        "Kom igjen, våkn opp!",
        "Nesten! Så nært!",
        "Beste kampen denne sesongen",
        "Dommeren så ingenting",
        "FOR EN PASNING!",
        "Utrolig ballkontroll",
        "Det var offside!",
        "Kom igjen da!",
        "Perfekt timing",
        "Dette blir episk",
        "KJØR PÅ!!!",
        "Hvilken spilling!",
        "Fantastisk lagspill",
        "Publikum er tent 🔥",
        "NÅ SKJER DET!",
    ]
    
    // MARK: - Initialization
    
    init(timeline: UnifiedTimelineManager? = nil) {
        self.timeline = timeline
    }
    
    // MARK: - Public Methods
    
    func startSimulation(withTimeline: Bool = false) {
        viewerCount = Int.random(in: 800...1500)
        
        if withTimeline, timeline != nil {
            // Don't add random messages - timeline will provide them
            // Just start viewer count updates
        } else {
            // Add initial messages (old behavior)
            for _ in 0..<4 {
                addSimulatedMessage()
            }
            
            // Schedule periodic messages
            scheduleNextMessage()
        }
        
        // Update viewer count periodically
        viewerTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let change = Int.random(in: -10...20)
            self.viewerCount = max(20, self.viewerCount + change)
        }
    }
    
    func stopSimulation() {
        timer?.invalidate()
        viewerTimer?.invalidate()
        timer = nil
        viewerTimer = nil
    }
    
    func addMessage(_ message: ChatMessage) {
        messages.append(message)
        if messages.count > maxMessages {
            messages.removeFirst()
        }
    }
    
    // MARK: - Private Methods
    
    private func scheduleNextMessage() {
        let interval = Double.random(in: 3.0...6.0)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.addSimulatedMessage()
            self?.scheduleNextMessage()
        }
    }
    
    private func addSimulatedMessage() {
        let user = simulatedUsers.randomElement()!
        let messageText = simulatedMessages.randomElement()!
        
        // Use timeline time if available, otherwise use estimated time
        let videoTime = timeline?.currentVideoTime ?? TimeInterval(messages.count * 60)
        
        let message = ChatMessage(
            username: user.0,
            text: messageText,
            usernameColor: user.1,
            likes: Int.random(in: 0...12),
            timestamp: Date(),
            videoTimestamp: videoTime
        )
        
        messages.append(message)
        
        // Add to timeline if available
        timeline?.addEvent(message.toTimelineEvent())
        
        if messages.count > maxMessages {
            messages.removeFirst()
        }
    }
    
    // MARK: - Timeline Integration
    
    /// Load messages from timeline (replaces simulation when using timeline)
    func loadMessagesFromTimeline() {
        guard let timeline = timeline else { return }
        let chatEvents = timeline.visibleChatMessages()
        let newMessages = chatEvents.map { event in
            ChatMessage(
                username: event.username,
                text: event.text,
                usernameColor: event.colorValue,
                likes: event.likes,
                timestamp: event.timestamp,
                videoTimestamp: event.videoTimestamp
            )
        }
        
        // Only update if different (prevent unnecessary updates)
        if newMessages.count != messages.count {
            messages = newMessages
        }
    }
}


