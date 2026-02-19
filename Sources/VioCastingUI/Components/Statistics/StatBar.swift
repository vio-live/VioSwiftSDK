//
//  StatBar.swift
//  Viaplay
//
//  Atomic component: Statistic progress bar
//

import SwiftUI

struct StatBar: View {
    let name: String
    let homeValue: Double
    let awayValue: Double
    let unit: String?
    let homeColor: Color
    let awayColor: Color
    
    init(
        name: String,
        homeValue: Double,
        awayValue: Double,
        unit: String? = nil,
        homeColor: Color = .purple,
        awayColor: Color = .white
    ) {
        self.name = name
        self.homeValue = homeValue
        self.awayValue = awayValue
        self.unit = unit
        self.homeColor = homeColor
        self.awayColor = awayColor
    }
    
    private var homePercentage: Double {
        let total = homeValue + awayValue
        return total > 0 ? (homeValue / total) * 100 : 50
    }
    
    private var awayPercentage: Double {
        return 100 - homePercentage
    }
    
    private func formatValue(_ value: Double, unit: String?) -> String {
        if let unit = unit {
            return String(format: "%.1f%@", value, unit)
        } else {
            return "\(Int(value))"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 100, alignment: .leading)
            
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(homeColor)
                        .frame(width: geometry.size.width * CGFloat(homePercentage / 100))
                    
                    Rectangle()
                        .fill(awayColor.opacity(0.3))
                        .frame(width: geometry.size.width * CGFloat(awayPercentage / 100))
                }
            }
            .frame(height: 6)
            .cornerRadius(3)
            
            HStack(spacing: 8) {
                Text(formatValue(homeValue, unit: unit))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, alignment: .trailing)
                
                Text(formatValue(awayValue, unit: unit))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, alignment: .leading)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StatBar(name: "Possession", homeValue: 56.3, awayValue: 43.7, unit: "%")
        StatBar(name: "Shots", homeValue: 12, awayValue: 5)
        StatBar(name: "Corners", homeValue: 7, awayValue: 3)
    }
    .padding()
    .background(Color(hex: "1B1B25"))
}


