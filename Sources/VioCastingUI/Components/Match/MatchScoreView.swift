//
//  MatchScoreView.swift
//  Viaplay
//
//  Atomic component: Match score display
//

import SwiftUI

struct MatchScoreView: View {
    let homeScore: Int
    let awayScore: Int
    let currentMinute: Int
    let isLive: Bool
    
    init(homeScore: Int, awayScore: Int, currentMinute: Int, isLive: Bool = true) {
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.currentMinute = currentMinute
        self.isLive = isLive
    }
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Text("\(homeScore)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                
                if isLive {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
                
                Text("\(awayScore)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text("\(currentMinute)'")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        MatchScoreView(homeScore: 0, awayScore: 0, currentMinute: 2)
        MatchScoreView(homeScore: 3, awayScore: 1, currentMinute: 87)
        MatchScoreView(homeScore: 2, awayScore: 2, currentMinute: 90, isLive: false)
    }
    .padding()
    .background(Color.black)
}


