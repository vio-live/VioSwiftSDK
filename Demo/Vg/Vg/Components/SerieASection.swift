import SwiftUI

struct SerieASection: View {
    let onSeeAllTapped: () -> Void
    let onCardTapped: (Int) -> Void
    
    private let cards = [
        (image: "card2x1", time: "I DAG 18:15", title: "Lecce - Napoli"),
        (image: "card2x2", time: "I DAG 20:30", title: "Atalanta - Milan")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Tidligere sendinger")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onSeeAllTapped) {
                    HStack(spacing: 4) {
                        Text("SE ALLE")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Cards scroll view
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<cards.count, id: \.self) { index in
                        WideCard(
                            imageName: cards[index].image,
                            time: cards[index].time,
                            title: cards[index].title
                        ) {
                            onCardTapped(index)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    SerieASection(
        onSeeAllTapped: {
            print("See all Serie A tapped")
        },
        onCardTapped: { index in
            print("Serie A card \(index) tapped")
        }
    )
    .background(Color.black)
    .padding()
}
