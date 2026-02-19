import SwiftUI

struct RentBuyCard: View {
    let title: String
    let imageUrl: String?
    let localImageName: String?
    let badge: String
    
    init(title: String, imageUrl: String? = nil, localImageName: String? = nil, badge: String) {
        self.title = title
        self.imageUrl = imageUrl
        self.localImageName = localImageName
        self.badge = badge
    }
    
    var body: some View {
        GeometryReader { geometry in
            // Image - prefer local image if available
            if let localImageName = localImageName {
                Image(localImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .cornerRadius(8)
            } else if let imageUrl = imageUrl {
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .cornerRadius(8)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                            .cornerRadius(8)
                    case .failure:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .cornerRadius(8)
                    @unknown default:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .cornerRadius(8)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .cornerRadius(8)
            }
        }
    }
}

#Preview {
    GeometryReader { geometry in
        let cardWidth = (geometry.size.width - 32 - 24) / 3
        
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                RentBuyCard(
                    title: "The Conjuring 4",
                    localImageName: "card1",
                    badge: "KINOAKTUE"
                )
                .frame(width: cardWidth, height: 180)
                
                RentBuyCard(
                    title: "Jurassic World",
                    localImageName: "card2",
                    badge: "Rent"
                )
                .frame(width: cardWidth, height: 180)
                
                RentBuyCard(
                    title: "Movie 1",
                    localImageName: "card3",
                    badge: "Buy"
                )
                .frame(width: cardWidth, height: 180)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(hex: "1B1B25"))
    }
}
