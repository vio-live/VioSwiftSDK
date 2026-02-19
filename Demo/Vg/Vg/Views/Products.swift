import SwiftUI
import VioUI
import VioCore

struct ProductsView: View {
    let onBackTapped: () -> Void    
    @EnvironmentObject var cartManager: CartManager
    
    var body: some View {
        ZStack {
            VGTheme.Colors.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: onBackTapped) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 16)
                
                VProductStore()
            }
        }
        .overlay {
            VFloatingCartIndicator()
            .environmentObject(cartManager)
        }
        .sheet(isPresented: $cartManager.isCheckoutPresented) {
            VCheckoutOverlay()
                .environmentObject(cartManager)
        }
    }    
}