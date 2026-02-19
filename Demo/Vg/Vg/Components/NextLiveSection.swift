import SwiftUI

struct NextLiveSection: View {
    let onSeeAllTapped: () -> Void
    let onCardTapped: (Int) -> Void
    
    private let cards = ["card1", "card2", "card3", "card4"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Cards scroll view (first)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(0..<cards.count, id: \.self) { index in
                        NextLiveCard(
                            imageName: cards[index],
                            isFirst: index == 0
                        ) {
                            onCardTapped(index)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Header (below cards)
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    NextLiveSection(
        onSeeAllTapped: {
            print("See all tapped")
        },
        onCardTapped: { index in
            print("Card \(index) tapped")
        }
    )
    .background(Color.black)
    .padding()
}
