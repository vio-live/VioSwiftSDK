//
//  FieldLinesView.swift
//  Viaplay
//
//  Football field lines (center circle, penalty areas, goals)
//

import SwiftUI

struct FieldLinesView: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            ZStack {
                // Outer border (3 sides only - no bottom for half field)
                Path { path in
                    path.move(to: CGPoint(x: 8, y: height))
                    path.addLine(to: CGPoint(x: 8, y: 8))
                    path.addLine(to: CGPoint(x: width - 8, y: 8))
                    path.addLine(to: CGPoint(x: width - 8, y: height))
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 2)
                
                // Midfield line (at bottom for half field)
                Path { path in
                    path.move(to: CGPoint(x: 8, y: height - 8))
                    path.addLine(to: CGPoint(x: width - 8, y: height - 8))
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 2)
                
                // Half center circle (at bottom, clipped to show only top half)
                Circle()
                    .trim(from: 0, to: 0.5)  // Only top half of circle
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: width * 0.28, height: width * 0.28)
                    .rotationEffect(.degrees(180))  // Rotate so arc is on top
                    .position(x: width / 2, y: height - 8)
                
                // Center spot
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .position(x: width / 2, y: height - 8)
                
                // Top penalty area
                Path { path in
                    let areaWidth = width * 0.6
                    let areaHeight = height * 0.15
                    let startX = (width - areaWidth) / 2
                    
                    path.move(to: CGPoint(x: startX, y: 8))
                    path.addLine(to: CGPoint(x: startX, y: areaHeight))
                    path.addLine(to: CGPoint(x: startX + areaWidth, y: areaHeight))
                    path.addLine(to: CGPoint(x: startX + areaWidth, y: 8))
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 2)
                
                // Top goal area (smaller)
                Path { path in
                    let goalWidth = width * 0.35
                    let goalHeight = height * 0.08
                    let startX = (width - goalWidth) / 2
                    
                    path.move(to: CGPoint(x: startX, y: 8))
                    path.addLine(to: CGPoint(x: startX, y: goalHeight))
                    path.addLine(to: CGPoint(x: startX + goalWidth, y: goalHeight))
                    path.addLine(to: CGPoint(x: startX + goalWidth, y: 8))
                }
                .stroke(Color.white.opacity(0.4), lineWidth: 2)
                
                // Penalty spot (only top one for half field)
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 4, height: 4)
                    .position(x: width / 2, y: height * 0.15)
            }
        }
    }
}

#Preview {
    FieldLinesView()
        .frame(width: 300, height: 450)
        .background(Color.black)
}
