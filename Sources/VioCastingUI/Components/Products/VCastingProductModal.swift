//
//  CastingProductModal.swift
//  Viaplay
//
//  Modal component for Casting product events
//  Goes directly to Casting checkout WebView
//

import SwiftUI
import VioCore

struct CastingProductModal: View {
    let productEvent: CastingProductEvent
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Direct to Casting checkout
            checkoutView
        }
    }
    
    // MARK: - Checkout View
    
    private var checkoutView: some View {
        VStack(spacing: 0) {
            // Header with logo aligned to left
            HStack(alignment: .center) {
                // Logo from VioConfiguration.dynamicBrandConfig (evita EXC_BAD_ACCESS)
                if let urlString = VioConfiguration.shared.dynamicBrandConfig?.logoUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 60, height: 30)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 30)
                        case .failure:
                            EmptyView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                
                Spacer()
                
                // Close button (X)
                Button(action: {
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // WebView with checkout
            if let checkoutUrl = productEvent.castingCheckoutUrl,
               let url = URL(string: checkoutUrl) {
                CastingCheckoutWebViewContainer(
                    url: url,
                    onDismiss: onDismiss,
                    onBack: nil
                )
            } else if let productUrl = productEvent.castingProductUrl,
                      let url = URL(string: productUrl) {
                // Fallback to product URL if checkout URL not available
                CastingCheckoutWebViewContainer(
                    url: url,
                    onDismiss: onDismiss,
                    onBack: nil
                )
            } else {
                // No URL available
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Checkout URL ikke tilgjengelig")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("Kontakt \(VioConfiguration.shared.effectiveBrandConfiguration.name) for å fullføre kjøpet")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
            }
        }
    }
}
