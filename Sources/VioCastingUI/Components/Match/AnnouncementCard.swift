//
//  AnnouncementCard.swift
//  Viaplay
//
//  Molecular component: Announcement card
//

import SwiftUI

struct AnnouncementCard: View {
    let announcement: AnnouncementEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon and title
            HStack(spacing: 10) {
                // Use sport icons instead of emojis
                ZStack {
                    Circle()
                        .fill(Color(red: 0.96, green: 0.08, blue: 0.42).opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: eventIcon(for: announcement.title))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.96, green: 0.08, blue: 0.42))
                }
                
                Text(cleanTitle(announcement.title))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Message
            Text(announcement.message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            
            // Action button if available
            if let actionText = announcement.actionText {
                Button(action: {}) {
                    Text(actionText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(red: 0.96, green: 0.08, blue: 0.42))
                        .cornerRadius(8)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
    }
    
    // MARK: - Helpers
    
    private func eventIcon(for title: String) -> String {
        if title.contains("Avspark") || title.contains("⚽") {
            return "soccerball.circle.fill"
        } else if title.contains("Pause") || title.contains("⏸") {
            return "pause.circle.fill"
        } else if title.contains("Fulltid") {
            return "flag.checkered.circle.fill"
        } else {
            return "megaphone.fill"
        }
    }
    
    private func cleanTitle(_ title: String) -> String {
        // Remove emojis from title
        title.replacingOccurrences(of: "⚽ ", with: "")
            .replacingOccurrences(of: "⏸ ", with: "")
            .replacingOccurrences(of: "🏁 ", with: "")
    }
}

#Preview {
    VStack(spacing: 16) {
        AnnouncementCard(
            announcement: AnnouncementEvent(
                id: "kickoff",
                videoTimestamp: 0,
                title: "⚽ Avspark",
                message: "Kampen starter! Barcelona vs PSG",
                imageUrl: nil,
                actionUrl: nil,
                actionText: nil,
                metadata: nil
            )
        )
        
        AnnouncementCard(
            announcement: AnnouncementEvent(
                id: "halftime",
                videoTimestamp: 2700,
                title: "⏸ Pause",
                message: "Første omgang ferdig. Stillingen er 2-0 til Barcelona.",
                imageUrl: nil,
                actionUrl: nil,
                actionText: "Se høydepunkter",
                metadata: nil
            )
        )
    }
    .padding()
    .background(Color(hex: "1B1B25"))
}
