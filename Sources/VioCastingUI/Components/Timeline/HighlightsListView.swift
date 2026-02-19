//
//  HighlightsListView.swift
//  Viaplay
//
//  Organism component: Highlights list
//

import SwiftUI

struct HighlightsListView: View {
    let highlights: [HighlightTimelineEvent]
    let currentMinute: Int
    let selectedMinute: Int?
    
    private var displayMinute: Int {
        selectedMinute ?? currentMinute
    }
    
    private var title: String {
        if let minute = selectedMinute {
            return "Høydepunkter til \(minute)'"
        }
        return "Høydepunkter"
    }
    
    // Filter highlights by current time
    private var visibleHighlights: [HighlightTimelineEvent] {
        highlights.filter { $0.displayMinute <= displayMinute }
            .sorted { $0.videoTimestamp > $1.videoTimestamp }  // Newest first
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(visibleHighlights.count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                // Highlight videos
                ForEach(visibleHighlights) { highlight in
                    HighlightVideoCard(highlight: highlight)
                        .padding(.horizontal, 16)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                
                if visibleHighlights.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "play.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("Ingen høydepunkter ennå")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(hex: "1B1B25"))
    }
}

#Preview {
    HighlightsListView(
        highlights: [
            HighlightTimelineEvent(
                id: "h1",
                videoTimestamp: 780,
                title: "MÅL: A. Diallo",
                description: "Nydelig avslutning!",
                thumbnailUrl: nil,
                clipUrl: "https://firebasestorage.googleapis.com/v0/b/tipio-1ec97.appspot.com/o/1.MP4?alt=media&token=898b7836-5e27-492d-82bb-9d7bb50f9d66",
                highlightType: .goal,
                metadata: nil
            )
        ],
        currentMinute: 45,
        selectedMinute: nil
    )
}


