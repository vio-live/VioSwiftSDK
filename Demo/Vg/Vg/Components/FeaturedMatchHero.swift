//
//  FeaturedMatchHero.swift
//  Vg
//
//  Created by Angelo Sepulveda on 28/10/2025.
//

import SwiftUI

struct FeaturedMatchHero: View {
    let time: String
    let title: String
    let category: String
    let description: String
    let onPlayTapped: () -> Void
    let onMatchTapped: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                Image("bg-sport")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: 520)
                    .clipped()
                
                LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0), Color.black.opacity(0), Color.black.opacity(0.7), Color.black.opacity(0.80)], startPoint: .top, endPoint: .bottom)
                    .frame(width: geometry.size.width, height: 520)
            
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(time)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white)
                                .cornerRadius(4)
                            Spacer()
                        }
                        .padding(.bottom, 2)
                        
                        HStack(alignment: .center, spacing: 0) {
                            Button(action: onMatchTapped) {
                                Text(title)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            Button(action: onPlayTapped) {
                                Circle()
                                    .fill(Color(red: 0.85, green: 0, blue: 0))
                                    .frame(width: 48, height: 48)
                                    .overlay(Image(systemName: "play.fill").font(.system(size: 18, weight: .bold)).foregroundColor(.white).offset(x: 2))
                            }
                        }
                        
                        Text(category)
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 2)
                            .padding(.bottom, 2)
                        
                        Text(description)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(3)
                            .padding(.top, 10)
                        
                        Text("VG+ Sport")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .frame(width: geometry.size.width)
                }
            }
            .frame(width: geometry.size.width, height: 520)
        }
        .frame(height: 520)
    }
}

#Preview {
    FeaturedMatchHero(
        time: "I dag 18:15",
        title: "Lecce - Napoli",
        category: "Sport",
        description: "Se italiensk Serie A direkte på VG+Sport. Lecce og Napoli møtes i niende serierunde på Stadio Via del Mare i Lecce. Vegard Aulstad står for kommenteringen.",
        onPlayTapped: {
            print("Play tapped")
        },
        onMatchTapped: {
            print("Match tapped")
        }
    )
}

