import SwiftUI

struct ContentCard: View {
    let imageName: String
    let title: String
    let subtitle: String
    let duration: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image with overlays
                ZStack(alignment: .bottomLeading) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 240, height: 140)
                        .clipped()
                        .cornerRadius(8)
                    
                    // VG+ Sport badge (bottom-left)
                    Text("VG+ Sport")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(3)
                        .padding(.leading, 6)
                        .padding(.bottom, 6)
                    
                    // Duration badge (bottom-right)
                    Text(duration)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(3)
                        .padding(.trailing, 6)
                        .padding(.bottom, 6)
                }
                
                // Text content below image
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                .frame(width: 240, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ContentCard(
        imageName: "card2x1",
        title: "Tondela - Sporting CP",
        subtitle: "Sport · 2. oktober",
        duration: "02:12:09"
    ) {
        print("Content card tapped")
    }
    .background(Color.black)
    .padding()
}
