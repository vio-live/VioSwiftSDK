import SwiftUI
import VioCore

#if os(iOS)
import PassKit

/// Apple Pay entry for product checkout (iOS). Uses `CartManager` from the environment.
public struct VApplePayButton: View {

    let product: Product?
    let variant: Variant?
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
        product: Product? = nil,
        variant: Variant? = nil,
        productName: String? = nil,
        productImageUrl: String? = nil,
        amount: Double? = nil,
        onPaymentComplete: (() -> Void)? = nil
    ) {
        self.product = product
        self.variant = variant

        let titleCandidate: String? = productName ?? product?.title
        self.productName = titleCandidate ?? "Product"

        let imageCandidate: String? = productImageUrl ?? product?.images.first?.url
        self.productImageUrl = imageCandidate

        let variantInclTax: Float? = variant?.price.amount_incl_taxes
        let variantAmount: Float? = variant.map { $0.price.amount }
        let productInclTax: Float? = product?.price.amount_incl_taxes
        let productAmount: Float? = product.map { $0.price.amount }
        let mergedUnit: Float? =
            variantInclTax ?? variantAmount ?? productInclTax ?? productAmount
        let unit: Float = mergedUnit ?? 0
        self.amount = amount ?? Double(unit)
        self.onPaymentComplete = onPaymentComplete
    }

    private func handlePaymentResultChange(_ newValue: ApplePayManager.PaymentResult?) {
        guard let result = newValue else { return }
        switch result {
        case .success:
            showConfirmation = true
        case .failure(let msg):
            errorMessage = msg
            showError = true
        case .cancelled:
            break
        }
    }

    public var body: some View {
        availabilityContent
            .onChange(of: applePayManager.paymentResult) { newValue in
                handlePaymentResultChange(newValue)
            }
            .sheet(isPresented: $showConfirmation, content: confirmationSheet)
            .alert(
                "Betaling feilet",
                isPresented: $showError,
                actions: {
                    Button("OK") { applePayManager.paymentResult = nil }
                },
                message: { Text(errorMessage) }
            )
    }

    private var availabilityContent: some View {
        Group {
            if applePayManager.isApplePayAvailable {
                applePayButton
            } else {
                unavailableView
            }
        }
    }

    @ViewBuilder
    private func confirmationSheet() -> some View {
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
        applePayManager.paymentResult = nil
        Task {
            await applePayManager.pay(
                product: product,
                variant: variant,
                productName: productName,
                amount: amount,
                checkoutId: cartManager.checkoutId ?? cartManager.cartId,
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
