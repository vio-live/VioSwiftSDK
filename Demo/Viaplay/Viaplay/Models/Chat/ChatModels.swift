//
//  ChatModels.swift
//  Viaplay
//
//  Chat data models - extracted for reusability
//  Compatible with UnifiedTimeline system
//

import Foundation
import SwiftUI

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let username: String
    let text: String
    let usernameColor: Color
    let likes: Int
    let timestamp: Date
    let videoTimestamp: TimeInterval  // NEW: Sync with video timeline
    
    init(
        username: String,
        text: String,
        usernameColor: Color,
        likes: Int,
        timestamp: Date = Date(),
        videoTimestamp: TimeInterval = 0
    ) {
        self.username = username
        self.text = text
        self.usernameColor = usernameColor
        self.likes = likes
        self.timestamp = timestamp
        self.videoTimestamp = videoTimestamp
    }
}

// MARK: - Helper Extensions

extension ChatMessage {
    /// Time ago from now (e.g., "5s", "2m", "1h")
    func timeAgo() -> String {
        let seconds = Int(Date().timeIntervalSince(timestamp))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        return "\(hours)h"
    }
    
    /// Display minute in match (e.g., "13'")
    var displayMinute: String {
        let minute = Int(videoTimestamp / 60)
        return "\(minute)'"
    }
    
    /// First letter of username for avatar
    var avatarInitial: String {
        String(username.prefix(1))
    }
    
    /// Convert to timeline event
    func toTimelineEvent() -> ChatMessageEvent {
        ChatMessageEvent(
            id: id.uuidString,
            videoTimestamp: videoTimestamp,
            username: username,
            text: text,
            usernameColor: usernameColor,
            likes: likes,
            timestamp: timestamp
        )
    }
}


