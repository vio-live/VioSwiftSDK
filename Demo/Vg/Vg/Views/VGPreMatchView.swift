import SwiftUI
import VioUI
import VioCore

struct VGPreMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showPlayer = false
    @EnvironmentObject private var cartManager: CartManager
    @EnvironmentObject private var checkoutDraft: CheckoutDraft
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image
                Image("bg")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()
                    .overlay(
                        // Dark overlay for better text readability
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                    )
                
                VStack {
                    // Close button
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    // Match title
                    VStack(spacing: 16) {
                        Text("Barcelona - PSG")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        // Play button
                        Button(action: { showPlayer = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Watch Live")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 28)
                            .background(VGTheme.Colors.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: VGTheme.Colors.red.opacity(0.6), radius: 12, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 60)
                }
                .frame(width: geometry.size.width)
            }
            
            // Floating cart indicator - always on top
            VFloatingCartIndicator(
                customPadding: EdgeInsets(top: 0, leading: 0, bottom: 80, trailing: 16)
            )
            .zIndex(10000)
        }
        .ignoresSafeArea()
        .fullScreenCover(isPresented: $showPlayer) {
            VGFullScreenPlayerView()
                .preferredColorScheme(.dark)
                .environmentObject(cartManager)
                .environmentObject(checkoutDraft)
        }
        .sheet(isPresented: $cartManager.isCheckoutPresented) {
            VCheckoutOverlay()
                .environmentObject(cartManager)
                .environmentObject(checkoutDraft)
        }
    }
}

#Preview {
    VGPreMatchView()
}

