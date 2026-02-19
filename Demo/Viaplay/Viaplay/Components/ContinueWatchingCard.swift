//
//  ContinueWatchingCard.swift
//  Viaplay
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI

struct ContinueWatchingCard: View {
    let item: ContinueWatchingItem
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                // Thumbnail Image
                AsyncImage(url: URL(string: item.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.2))
                }
                .frame(width: 160, height: 230)
                .clipped()
                .cornerRadius(12)
                
                // Rent Label (top left corner)
                if let rentLabel = item.rentLabel {
                    Text(rentLabel)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(5)
                        .padding(10)
                }
                
                // Progress bar at bottom
                VStack {
                    Spacer()
                    
                    // Progress indicator with gradient
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background track
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 3)
                            
                            // Progress with gradient
                            LinearGradient(
                                colors: [Color(red: 0.4, green: 0.8, blue: 1.0), Color(red: 1.0, green: 0.4, blue: 0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: geo.size.width * item.progress, height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                
                // Crown icon at bottom center (for items without rent label)
                if item.rentLabel == nil {
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.35, green: 0.35, blue: 0.38))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                        }
                        .offset(y: 25) // Half outside the card
                    }
                }
                
                // Three dots menu (top right)
                VStack {
                    HStack {
                        Spacer()
                        
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(90))
                            .padding(10)
                    }
                    
                    Spacer()
                }
            }
            .frame(width: 160, height: 230)
            
            // Time remaining label
            Text("\(Int(item.progress * 100)) min left")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ContinueWatchingCard(item: ContinueWatchingItem.mockItems[0])
        ContinueWatchingCard(item: ContinueWatchingItem.mockItems[1])
        ContinueWatchingCard(item: ContinueWatchingItem.mockItems[2])
    }
    .padding()
    .background(Color.black)
}
