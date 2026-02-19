import SwiftUI
import VioUI
import VioCore

struct VGFullScreenPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var cartManager: CartManager
    @EnvironmentObject private var checkoutDraft: CheckoutDraft
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VGVideoPlayer()
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .padding(.leading, 12)
                    .padding(.top, 10)
                    Spacer()
                }
                Spacer()
            }
            .zIndex(100)
            
            // Floating cart indicator - always on top
            VFloatingCartIndicator(
                customPadding: EdgeInsets(top: 0, leading: 0, bottom: 80, trailing: 16)
            )
            .zIndex(10000)
        }
        .sheet(isPresented: $cartManager.isCheckoutPresented) {
            VCheckoutOverlay()
                .environmentObject(cartManager)
                .environmentObject(checkoutDraft)
        }
    }
}


