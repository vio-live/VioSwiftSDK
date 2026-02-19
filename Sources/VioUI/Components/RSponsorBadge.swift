import SwiftUI

/// Sponsor badge component for displaying campaign sponsor logo
/// Shows "Sponset av" text above the logo image
/// Used in product carousels and other product display components
///
/// **Usage:**
/// ```swift
/// RSponsorBadge(logoUrl: "https://example.com/logo.png")
/// ```
///
/// **Parameters:**
/// - `logoUrl: String` - URL of the sponsor logo image (from campaign configuration)
///
/// **Design:**
/// - Small compact size (60x30 max for logo, 8pt font for text)
/// - Text "Sponset av" displayed above logo
/// - Minimal padding for compact display
public struct RSponsorBadge: View {
    let logoUrl: String
    
    public init(logoUrl: String) {
        self.logoUrl = logoUrl
    }
    
    public var body: some View {
        VStack(spacing: 2) {
            // Texto "Sponset av" arriba
            Text("Sponset av")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            // Logo abajo
            AsyncImage(url: URL(string: logoUrl)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 50, height: 25)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 60, maxHeight: 30)
                case .failure:
                    Image(systemName: "photo")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(width: 50, height: 25)
                @unknown default:
                    EmptyView()
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        
        RSponsorBadge(logoUrl: "https://via.placeholder.com/100x40")
    }
}
