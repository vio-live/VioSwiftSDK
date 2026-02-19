//
//  TimelineMinuteBadge.swift
//  Viaplay
//
//  Atomic component: Minute indicator for timeline events
//

import SwiftUI

struct TimelineMinuteBadge: View {
    let minute: Int
    let showConnector: Bool
    let connectorHeight: CGFloat
    
    init(minute: Int, showConnector: Bool = false, connectorHeight: CGFloat = 40) {
        self.minute = minute
        self.showConnector = showConnector
        self.connectorHeight = connectorHeight
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("\(minute)'")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 50)
            
            if showConnector {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 2, height: connectorHeight)
            }
        }
    }
}

#Preview {
    HStack(spacing: 32) {
        TimelineMinuteBadge(minute: 13)
        TimelineMinuteBadge(minute: 45, showConnector: true)
        TimelineMinuteBadge(minute: 90, showConnector: true, connectorHeight: 60)
    }
    .padding()
    .background(Color.black)
}


