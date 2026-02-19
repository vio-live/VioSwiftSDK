import SwiftUI

/// Badge de sponsor para mostrar en la esquina inferior derecha de los overlays
struct TV2SponsorBadge: View {
    let logoUrl: String
    
    var body: some View {
        VStack(spacing: 4) {
            // Logo arriba
            AsyncImage(url: URL(string: logoUrl)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 80, height: 40)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 100, maxHeight: 50)
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 80, height: 40)
                @unknown default:
                    EmptyView()
                }
            }
            
            // Texto "Sponset av" abajo
            Text("Sponset av")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        
        TV2SponsorBadge(logoUrl: "https://via.placeholder.com/100x40")
    }
}

