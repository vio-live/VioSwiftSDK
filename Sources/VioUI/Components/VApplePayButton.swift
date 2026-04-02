import SwiftUI
import VioCore

#if os(iOS)
import PassKit

/// Apple Pay entry for product checkout (iOS). Uses `CartManager` from the environment.
public struct VApplePayButton: View {

    let productName: String
    let productImageUrl: String?
    let amount: Double
    let onPaymentComplete: (() -> Void)?

    @EnvironmentObject private var cartManager: CartManager
    @ObservedObject private var applePayManager = ApplePayManager.shared
    @State private var showConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    public init(
        productName: String,
        productImageUrl: String? = nil,
        amount: Double,
        onPaymentComplete: (() -> Void)? = nil
    ) {
        self.productName = productName
        self.productImageUrl = productImageUrl
        self.amount = amount
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
        .onChange(of: applePayManager.paymentResult) { newValue in
            switch newValue {
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
                amount: amount,
                currencyCode: cartManager.currency,
                contact: applePayManager.capturedContact
            ) {
                showConfirmation = false
                applePayManager.paymentResult = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onPaymentComplete?()
                }
            }
            .applyApplePaySheetChrome()
        }
        .alert("Betaling feilet", isPresented: $showError) {
            Button("OK") { applePayManager.paymentResult = nil }
        } message: {
            Text(errorMessage)
        }
    }

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
            .background(Color(red: 0.44, green: 0.0, blue: 1.0))
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

    private func initiatePayment() {
        Task {
            await applePayManager.pay(
                productName: productName,
                amount: amount,
                cartManager: cartManager
            )
        }
    }
}

private extension View {
    @ViewBuilder
    func applyApplePaySheetChrome() -> some View {
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

#else

/// Placeholder on non‑iOS platforms (Apple Pay is iOS-only).
public struct VApplePayButton: View {
    public init(
        productName: String,
        productImageUrl: String? = nil,
        amount: Double,
        onPaymentComplete: (() -> Void)? = nil
    ) {}

    public var body: some View { EmptyView() }
}

#endif
