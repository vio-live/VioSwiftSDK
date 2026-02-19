//
//  ChatModels.swift
//  VioCastingUI
//

import Foundation
import SwiftUI

// MARK: - Chat Message
public struct ChatMessage: Identifiable {
    public let id: UUID
    public let username: String
    public let text: String
    public let usernameColor: Color
    public let likes: Int
    public let timestamp: Date
    public let videoTimestamp: TimeInterval

    public init(
        id: UUID = UUID(),
        username: String,
        text: String,
        usernameColor: Color,
        likes: Int,
        timestamp: Date = Date(),
        videoTimestamp: TimeInterval = 0
    ) {
        self.id = id
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
    public func timeAgo() -> String {
        let seconds = Int(Date().timeIntervalSince(timestamp))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        return "\(hours)h"
    }

    public var displayMinute: String {
        let minute = Int(videoTimestamp / 60)
        return "\(minute)'"
    }

    public var avatarInitial: String {
        String(username.prefix(1))
    }

    public func toTimelineEvent() -> ChatMessageEvent {
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
