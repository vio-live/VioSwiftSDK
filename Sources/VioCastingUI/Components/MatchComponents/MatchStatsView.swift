//
//  MatchStatsView.swift
//  Viaplay
//
//  Componente reutilizable para mostrar estadísticas del partido
//

import SwiftUI

struct MatchStatsView: View {
    let statistics: MatchStatistics
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(statistics.stats) { stat in
                        statRow(stat)
                            .padding(.horizontal, 12)
                    }
                }
                .padding(.vertical, 8)
                .frame(width: geometry.size.width)
            }
            .frame(width: geometry.size.width)
            .background(Color(hex: "1B1B25"))
        }
    }
    
    // MARK: - Stat Row
    
    private func statRow(_ stat: Statistic) -> some View {
        VStack(spacing: 8) {
            // Stat Name
            Text(stat.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity)
            
            // Values and Bar
            HStack(spacing: 8) {
                // Home Value
                Text(formatValue(stat.homeValue, unit: stat.unit))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 50, alignment: .trailing)
                    .minimumScaleFactor(0.8)
                
                // Bar Graph
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Home bar
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: geometry.size.width * CGFloat(stat.homePercentage / 100))
                        
                        // Away bar
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: geometry.size.width * CGFloat(stat.awayPercentage / 100))
                    }
                }
                .frame(height: 8)
                .cornerRadius(4)
                
                // Away Value
                Text(formatValue(stat.awayValue, unit: stat.unit))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 50, alignment: .leading)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 16)
        .background(
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }
    
    // MARK: - Helpers
    
    private func formatValue(_ value: Double, unit: String?) -> String {
        if let unit = unit {
            return String(format: "%.1f%@", value, unit)
        } else {
            return "\(Int(value))"
        }
    }
}

// MARK: - Preview

#Preview {
    MatchStatsView(statistics: .mock(for: Match.barcelonaPSG))
        .preferredColorScheme(.dark)
}

