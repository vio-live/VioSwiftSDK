import SwiftUI
import PassKit
import VioCore

/// Apple Pay button for Vio product checkout
public struct VApplePayButton: View {

    let productName: String
    let productImageUrl: String?
    let priceNOK: Double
    let onPaymentComplete: (() -> Void)?

    @StateObject private var applePayManager = ApplePayManager.shared
    @State private var showConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    public init(productName: String, productImageUrl: String? = nil, priceNOK: Double, onPaymentComplete: (() -> Void)? = nil) {
        self.productName = productName
        self.productImageUrl = productImageUrl
        self.priceNOK = priceNOK
        self.onPaymentComplete = onPaymentComplete
    }

    public var body: some View {
        Group {
            if applePayManager.isApplePayAvailable {
                applePayButton
            } else {
                unavailableView
            }
        }
        .onChange(of: applePayManager.paymentResult) { result in
            switch result {
            case .success:
                showConfirmation = true
            case .failed(let msg):
                errorMessage = msg
                showError = true
            case .cancelled, .none:
                break
            }
        }
        .sheet(isPresented: $showConfirmation) {
            VApplePayConfirmationSheet(
                productName: productName,
                productImageUrl: productImageUrl,
                priceNOK: priceNOK,
                contact: applePayManager.capturedContact
            ) {
                showConfirmation = false
                applePayManager.paymentResult = nil
                // Small delay so the sheet animates out before closing product
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onPaymentComplete?()
                }
            }
            .applyIfAvailable()
        }
        .alert("Betaling feilet", isPresented: $showError) {
            Button("OK") { applePayManager.paymentResult = nil }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Apple Pay Button
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
            .background(Color(red: 0.44, green: 0.0, blue: 1.0)) // #7000FF
            .cornerRadius(12)
        }
        .disabled(applePayManager.isProcessing)
        .preferredColorScheme(.dark)
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


// MARK: - iOS version-gated sheet modifiers
private extension View {
    @ViewBuilder
    func applyIfAvailable() -> some View {
        if #available(iOS 16.4, *) {
            self
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(Color(red: 0.08, green: 0.08, blue: 0.12))
                .presentationCornerRadius(28)
        } else if #available(iOS 16.0, *) {
            self
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
        } else {
            self
        }
    }
}
