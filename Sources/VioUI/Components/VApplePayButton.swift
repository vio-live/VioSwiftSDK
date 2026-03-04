import SwiftUI
import PassKit
import VioCore

/// Apple Pay button for Vio product checkout
/// Drop-in replacement for the "Kjøp" button in VProductDetailOverlay
public struct VApplePayButton: View {

    let productName: String
    let priceNOK: Double

    @StateObject private var applePayManager = ApplePayManager.shared
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""

    public init(productName: String, priceNOK: Double) {
        self.productName = productName
        self.priceNOK = priceNOK
    }

    public var body: some View {
        Group {
            if applePayManager.isApplePayAvailable {
                applePayButton
            } else {
                // Fallback: standard buy button if Apple Pay not available
                unavailableView
            }
        }
        .onChange(of: applePayManager.paymentResult) { result in
            switch result {
            case .success:
                showSuccess = true
            case .failed(let msg):
                errorMessage = msg
                showError = true
            case .cancelled, .none:
                break
            }
        }
        .alert("Betaling godkjent ✅", isPresented: $showSuccess) {
            Button("OK") { applePayManager.paymentResult = nil }
        } message: {
            Text("Din ordre for \(productName) er bekreftet.")
        }
        .alert("Betaling feilet", isPresented: $showError) {
            Button("OK") { applePayManager.paymentResult = nil }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Apple Pay Button (PKPaymentButton style)
    private var applePayButton: some View {
        Button(action: initiatePayment) {
            HStack(spacing: 8) {
                if applePayManager.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Pay")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .cornerRadius(12)
        }
        .disabled(applePayManager.isProcessing)
    }

    private var unavailableView: some View {
        Text("Apple Pay not available")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(12)
    }

    // MARK: - Action
    private func initiatePayment() {
        // CartManager needs to exist — use shared instance
        // In production this would use the active CartManager from the view hierarchy
        let cartManager = CartManager()
        Task {
            await applePayManager.pay(
                productName: productName,
                priceNOK: priceNOK,
                cartManager: cartManager
            )
        }
    }
}
