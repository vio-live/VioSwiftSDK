import SwiftUI

struct WideCard: View {
    let imageName: String
    let time: String
    let title: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image with VG+ Sport overlay
                ZStack(alignment: .bottomLeading) {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 180, height: 120)
                        .clipped()
                        .cornerRadius(8, corners: [.topLeft, .topRight])
                    
                    // VG+ Sport badge overlay
                    Text("VG+ Sport")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        .padding(.leading, 8)
                        .padding(.bottom, 8)
                }
                
                // Text content below image
                VStack(alignment: .leading, spacing: 2) {
                    Text(time)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .frame(width: 180, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Extension for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    HStack(spacing: 12) {
        WideCard(
            imageName: "card2x1",
            time: "I DAG 18:15",
            title: "Lecce - Napoli"
        ) {
            print("Card tapped")
        }
        
        WideCard(
            imageName: "card2x2",
            time: "I DAG 20:30",
            title: "Atalanta - Milan"
        ) {
            print("Card tapped")
        }
    }
    .background(Color.black)
    .padding()
}
