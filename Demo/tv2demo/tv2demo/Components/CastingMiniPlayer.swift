import SwiftUI

/// Mini player que se muestra en la parte inferior cuando hay casting activo
struct CastingMiniPlayer: View {
    @StateObject private var castingManager = CastingManager.shared
    let onTap: () -> Void
    
    @State private var isPlaying = true
    
    var body: some View {
        if castingManager.isCasting {
            VStack(spacing: 0) {
                Spacer()
                
                miniPlayerCard
                    .padding(.bottom, 90) // Justo sobre el tab bar (altura del tab bar ~50px + safe area)
            }
        }
    }
    
    private var miniPlayerCard: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail pequeño con campo de fútbol
                Image("football_field_bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipped()
                    .cornerRadius(6)
                
                // Match info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kolbotn - Nordstrand 2")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("4. divisjon, menn Fotball")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "666666"))
                }
                
                Spacer()
                
                // Botón de pausa circular
                Button(action: { isPlaying.toggle() }) {
                    ZStack {
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                Color.white
            )
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: -2)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 12)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        CastingMiniPlayer {
            print("Tapped mini player")
        }
    }
}

