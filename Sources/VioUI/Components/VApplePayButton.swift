import SwiftUI
import VioCore
import VioDesignSystem

#if os(iOS)
import PassKit

/// Apple Pay entry for product checkout (iOS). Uses `CartManager` from the environment.
public struct VApplePayButton: View {

    let product: Product?
    let variant: Variant?
    let productName: String
    let productImageUrl: String?
    let amount: Double
    let sponsorId: Int?
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
        sponsorId: Int? = nil,
        onPaymentComplete: (() -> Void)? = nil
    ) {
        self.product = product
        self.variant = variant
        self.sponsorId = sponsorId
        
        // Resolve product name
        let resolvedProductName: String
        if let productName = productName {
            resolvedProductName = productName
        } else if let productTitle = product?.title {
            resolvedProductName = productTitle
        } else {
            resolvedProductName = "Product"
        }
        self.productName = resolvedProductName
        
        // Resolve product image URL
        let resolvedImageUrl: String?
        if let productImageUrl = productImageUrl {
            resolvedImageUrl = productImageUrl
        } else {
            resolvedImageUrl = product?.images.first?.url
        }
        self.productImageUrl = resolvedImageUrl
        
        // Resolve amount
        let resolvedAmount: Double
        if let amount = amount {
            resolvedAmount = amount
        } else {
            // Try variant prices first
            let variantAmountIncl = variant?.price.amount_incl_taxes
            let variantAmount = variant?.price.amount
            
            // Try product prices as fallback
            let productAmountIncl = product?.price.amount_incl_taxes
            let productAmount = product?.price.amount
            
            if let variantAmountIncl = variantAmountIncl {
                resolvedAmount = Double(variantAmountIncl)
            } else if let variantAmount = variantAmount {
                resolvedAmount = Double(variantAmount)
            } else if let productAmountIncl = productAmountIncl {
                resolvedAmount = Double(productAmountIncl)
            } else if let productAmount = productAmount {
                resolvedAmount = Double(productAmount)
            } else {
                resolvedAmount = 0
            }
        }
        self.amount = resolvedAmount
        
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
            case .failure(let msg):
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
                contact: applePayManager.capturedContact,
                sponsorId: sponsorId
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
            // Apple's standard "black" Apple Pay button style — black bg
            // + white logo + white "Pay" text. Matches Apple's HIG and
            // PKPaymentButtonStyle.black. Hosts that want a custom tint
            // can wrap this in their own button surface.
            .background(Color.black)
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
        print("🚀 [VApplePayButton] initiatePayment tapped for product: \(productName), amount: \(amount), sponsorId: \(sponsorId.map(String.init) ?? "-")")
        applePayManager.paymentResult = nil
        Task {
            // Q4 L3 (2026-04-30): when this button is rendered inside a
            // SponsorCheckoutSection (multi-sponsor cart), `sponsorId` is
            // set and ApplePayManager routes the entire flow through the
            // sponsor's per-channel SDK. Single-sponsor / legacy paths
            // pass nil and the manager falls back to cartManager.sdk.
            //
            // The `checkoutId` we pass is the sponsor cart's checkoutId
            // when available; otherwise nil so ApplePayManager creates a
            // fresh one via createCheckout(forSponsor:) — also routed
            // through the sponsor's SDK.
            let resolvedCheckoutId: String? = {
                if let sid = sponsorId {
                    return cartManager.sponsorCart(forSponsorId: sid)?.checkoutId
                }
                return cartManager.checkoutId
            }()
            await applePayManager.pay(
                product: product,
                variant: variant,
                productName: productName,
                amount: amount,
                checkoutId: resolvedCheckoutId,
                sponsorId: sponsorId,
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
                // Match the sheet content's `surface` so the container rim
                // around the rounded inner card doesn't flash a different
                // tone (was TV2 dark navy `#141520` hardcoded — that bled
                // through to the underlying product modal during the sheet
                // transition on iOS 26, making it look black).
                .presentationBackground(VioColors.surface)
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

/// Placeholder on non‑iOS platforms (Apple Pay is iOS-only). The full set of
/// parameters mirrors the iOS branch — including the Q4 (2026-04-30)
/// `product`, `variant`, and `sponsorId` — so call sites don't need
/// `#if os(iOS)` guards just to switch parameter shapes.
public struct VApplePayButton: View {
    public init(
        product: Product? = nil,
        variant: Variant? = nil,
        productName: String? = nil,
        productImageUrl: String? = nil,
        amount: Double? = nil,
        sponsorId: Int? = nil,
        onPaymentComplete: (() -> Void)? = nil
    ) {}

    public var body: some View { EmptyView() }
}

#endif
