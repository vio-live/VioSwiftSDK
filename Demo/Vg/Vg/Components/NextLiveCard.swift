import SwiftUI

struct NextLiveCard: View {
    let imageName: String
    let isFirst: Bool
    let onTap: () -> Void
    
    private var cardSize: (width: CGFloat, height: CGFloat) {
        if isFirst {
            return (width: 160, height: 200)
        } else {
            return (width: 120, height: 160)
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: cardSize.width, height: cardSize.height)
                .clipped()
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HStack(spacing: 12) {
        NextLiveCard(
            imageName: "card1",
            isFirst: true
        ) {
            print("First card tapped")
        }
        
        NextLiveCard(
            imageName: "card2",
            isFirst: false
        ) {
            print("Card tapped")
        }
        
        NextLiveCard(
            imageName: "card3",
            isFirst: false
        ) {
            print("Card tapped")
        }
    }
    .background(Color.black)
    .padding()
}
