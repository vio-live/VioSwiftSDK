import SwiftUI

struct CategoryCard: View {
    let title: String
    let imageUrl: String?
    let localImageName: String?
    let seasonEpisode: String?
    
    init(title: String, imageUrl: String? = nil, localImageName: String? = nil, seasonEpisode: String? = nil) {
        self.title = title
        self.imageUrl = imageUrl
        self.localImageName = localImageName
        self.seasonEpisode = seasonEpisode
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
                CategoryCard(
                    title: "Norske Truckers",
                    localImageName: "card1",
                    seasonEpisode: "S3 | E2"
                )
                .frame(width: cardWidth, height: 180)
                
                CategoryCard(
                    title: "Kraven The Hunter",
                    localImageName: "card2",
                    seasonEpisode: nil
                )
                .frame(width: cardWidth, height: 180)
                
                CategoryCard(
                    title: "Paradise Hotel",
                    localImageName: "card3",
                    seasonEpisode: "S17 | E28"
                )
                .frame(width: cardWidth, height: 180)
            }
            .padding(.horizontal, 16)
        }
        .background(Color(hex: "1B1B25"))
    }
}
