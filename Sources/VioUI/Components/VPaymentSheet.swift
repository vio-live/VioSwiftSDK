import SwiftUI
import VioCore

/// Unified payment sheet — shows available payment methods based on campaign backend config
/// Replaces hardcoded checkout buttons. Reads VioConfiguration.shared.checkoutConfig
public struct VPaymentSheet: View {

    let productName: String
    let productImageUrl: String?
    let priceNOK: Double
    let onPaymentComplete: (() -> Void)?

    private var config: CheckoutConfig {
        VioConfiguration.shared.checkoutConfig
    }

    public init(
        productName: String,
        productImageUrl: String? = nil,
        priceNOK: Double,
        onPaymentComplete: (() -> Void)? = nil
    ) {
        self.productName = productName
        self.productImageUrl = productImageUrl
        self.priceNOK = priceNOK
        self.onPaymentComplete = onPaymentComplete
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Apple Pay — siempre visible (default y cuando backend lo incluye)
            VApplePayButton(
                productName: productName,
                productImageUrl: productImageUrl,
                priceNOK: priceNOK,
                onPaymentComplete: onPaymentComplete
            )

            // Klarna — solo si el backend lo habilita explícitamente
            if config.hasKlarna {
                klarnaButton
            }

            // Vipps — solo si el backend lo habilita explícitamente
            if config.hasVipps {
                vippsButton
            }
        }
    }

    // MARK: - Klarna Button
    private var klarnaButton: some View {
        Button(action: { /* TODO: initiate Klarna */ }) {
            HStack(spacing: 8) {
                Text("Klarna")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(red: 1.0, green: 0.7, blue: 0.8)) // Klarna pink
            .cornerRadius(12)
        }
    }

    // MARK: - Vipps Button
    private var vippsButton: some View {
        Button(action: { /* TODO: initiate Vipps */ }) {
            HStack(spacing: 8) {
                Text("Vipps")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(red: 1.0, green: 0.37, blue: 0.0)) // Vipps orange
            .cornerRadius(12)
        }
    }
}
