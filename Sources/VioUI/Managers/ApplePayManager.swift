import Foundation
import SwiftUI
import VioCore

#if os(iOS)
import Contacts
import PassKit
import StripeApplePay
import StripePayments

// Orchestrates PKPaymentRequest + optional Stripe via CartManager.stripeIntent().
@MainActor
public final class ApplePayManager: NSObject, ObservableObject {

    public static let shared = ApplePayManager()
    private let logComponent = "ApplePayManager"

    // Default merchant id used by PassKit. Backend may override it via applePayInit
    // only when it returns a valid Apple merchant identifier (`merchant.*`).
    private var merchantIdentifier: String = "merchant.live.vio"
    /// Same list on `PKPaymentRequest` and for PassKit probes. Maestro covers many NO/EU debit wallets; avoid rare networks that can make the aggregate `canMakePayments(usingNetworks:…)` falsely negative in some regions.
    private let supportedNetworks: [PKPaymentNetwork] = [
        .visa,
        .masterCard,
        .amex,
        .maestro,
        .vPay,
        .discover,
        .chinaUnionPay
    ]

    @Published public var isProcessing = false
    @Published public var paymentResult: PaymentResult?

    public enum PaymentResult: Equatable {
        case success
        case failure(String)
        case cancelled
    }

    public var isApplePayAvailable: Bool {
        PKPaymentAuthorizationController.canMakePayments()
    }
    
    /// Validates Apple Pay configuration and provides diagnostic information
    public func validateConfiguration() -> (isValid: Bool, issues: [String]) {
        var issues: [String] = []
        
        // Check basic Apple Pay availability
        if !PKPaymentAuthorizationController.canMakePayments() {
            issues.append("Apple Pay not available on this device")
        }
        
        if !PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks) {
            issues.append("No supported payment networks available")
        }
        
        // Check merchant identifier
        if merchantIdentifier.isEmpty {
            issues.append("Merchant identifier is empty")
        } else if !merchantIdentifier.hasPrefix("merchant.") {
            issues.append("Invalid merchant identifier format (should start with 'merchant.')")
        } else {
            // Try to detect entitlement issues early
            let testRequest = PKPaymentRequest()
            testRequest.merchantIdentifier = merchantIdentifier
            testRequest.supportedNetworks = [.visa]
            testRequest.merchantCapabilities = [.capability3DS]
            testRequest.countryCode = "US"
            testRequest.currencyCode = "USD"
            testRequest.paymentSummaryItems = [PKPaymentSummaryItem(label: "Test", amount: NSDecimalNumber(value: 1.0))]
            
            // Note: This doesn't fully validate entitlements, but gives us a basic check
            if !PKPaymentAuthorizationController.canMakePayments() {
                issues.append("Device doesn't support Apple Pay or merchant not entitled")
            }
        }
        
        // Check Stripe configuration
        if STPAPIClient.shared.publishableKey?.isEmpty ?? true {
            issues.append("Stripe publishable key not configured")
        }
        
        return (isValid: issues.isEmpty, issues: issues)
    }
    
    /// Diagnoses Apple Pay certificate and Stripe configuration
    public func diagnoseApplePaySetup() {
        guard isDebugBuild else {
            VioLogger.info("Apple Pay diagnosis skipped in non-DEBUG build", component: logComponent)
            return
        }
        VioLogger.debug("Apple Pay diagnosis started", component: logComponent)
        VioLogger.debug(
            "Device capabilities: canPay=\(PKPaymentAuthorizationController.canMakePayments()) canPayNetworks=\(PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks))",
            component: logComponent
        )
        VioLogger.debug(
            "Merchant configuration: merchantId=\(merchantIdentifier) build=\(isDebugBuild ? "DEBUG" : "RELEASE")",
            component: logComponent
        )

        if let key = STPAPIClient.shared.publishableKey {
            VioLogger.debug(
                "Stripe key configured: \(maskedStripeKey(key)) type=\(key.hasPrefix("pk_test_") ? "TEST" : key.hasPrefix("pk_live_") ? "LIVE" : "UNKNOWN")",
                component: logComponent
            )
        } else {
            VioLogger.warning("Stripe publishable key is not set", component: logComponent)
        }
        VioLogger.debug(
            "Required actions: verify merchant, generate cert, upload cert to Stripe, align test/live environments",
            component: logComponent
        )
    }
    
    private var isDebugBuild: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    private var pendingCheckoutId: String?
    public var capturedContact: PKContact?
    private var pendingPublishableKey: String?
    private var pendingCartManager: CartManager?
    /// Q4 L3 (2026-04-30): when set, the active payment is for a specific
    /// sponsor's cart in `cartsBySponsor[sponsorId]`. All SDK calls
    /// (cart.getById, payment.stripeIntent, payment.applePayInit,
    /// payment.applePayConfirm, checkout.create) get routed through that
    /// sponsor's commerce_api_key via `CommerceSdkClientProvider
    /// .client(forSponsorId:)` instead of the cartManager's global SDK.
    /// Nil means legacy single-cart flow (preserves back-compat).
    private var pendingSponsorId: Int?

    /// Q4 L3 (2026-04-30): resolves the SDK client to use for the active
    /// payment. When `pendingSponsorId` is set, returns the sponsor's
    /// per-channel client; otherwise falls back to `cartManager.sdk`
    /// (legacy single-cart). Used by `pay`, `tokenizeAndConfirm`,
    /// `resolveBackendStripeKey`, `extractStripeKeyFromApplePayInit`.
    private func sdkForActivePayment(_ cartManager: CartManager) -> CartManagingSDK {
        if let sid = pendingSponsorId,
           let sponsorSdk = try? CommerceSdkClientProvider.shared.client(
               forSponsorId: sid,
               configuration: VioConfiguration.shared
           ),
           CommerceSdkClientProvider.shared.activeSponsorId == sid {
            return sponsorSdk
        }
        return cartManager.sdk
    }

    public func pay(
        product: Product? = nil,
        variant: Variant? = nil,
        productName: String? = nil,
        amount: Double? = nil,
        checkoutId: String? = nil,
        sponsorId: Int? = nil,
        cartManager: CartManager
    ) async {
        self.isProcessing = true
        self.paymentResult = nil
        self.pendingCartManager = cartManager
        // Q4 L3 (2026-04-30): when sponsorId is set, every SDK call
        // below routes through this sponsor's commerce_api_key via
        // sdkForActivePayment(_:). Nil = legacy single-cart flow.
        self.pendingSponsorId = sponsorId
        guard await cartManager.ensurePaymentRuntimeReady(component: "ApplePayManager") else {
            paymentResult = .failure("Cart is not ready. Please try again.")
            isProcessing = false
            return
        }

        // Add product locally if provided. In sponsor-aware mode, route
        // through the sponsor-aware overload so the item lands in
        // `cartsBySponsor[sponsorId]` instead of the legacy items array.
        if let p = product {
            if let sid = sponsorId {
                await cartManager.addProduct(p, variant: variant, quantity: 1, sponsorId: sid)
            } else {
                await cartManager.addProduct(p, variant: variant, quantity: 1)
            }
        }

        // Resolve the active cart id: sponsor's cart when sponsorId set,
        // legacy `cartManager.cartId` otherwise.
        let activeCartId: String?
        if let sid = sponsorId {
            activeCartId = cartManager.sponsorCart(forSponsorId: sid)?.cartId
        } else {
            activeCartId = cartManager.cartId
        }
        guard let currentCartId = activeCartId, !currentCartId.isEmpty else {
            VioLogger.warning(
                "Apple Pay: missing cartId (sponsorId=\(sponsorId.map(String.init) ?? "-"))",
                component: "ApplePayManager"
            )
            paymentResult = .failure("Cart is not ready. Please try again.")
            isProcessing = false
            return
        }

        // Sync cart from server. In sponsor mode we already trust the
        // SponsorCart state (kept in sync by addProduct/removeItem/
        // updateQuantity in CartModule+SponsorCart.swift), so we skip
        // the legacy `cartManager.sync(from:)` which would overwrite
        // global state with this sponsor's cart only.
        do {
            cartManager.syncSdkCredentials()
            let activeSdk = sdkForActivePayment(cartManager)
            let serverCart = try await activeSdk.cart.getById(cart_id: currentCartId)
            if sponsorId == nil {
                cartManager.sync(from: serverCart)
            }
        } catch {
            VioLogger.error(
                "Apple Pay: failed to sync cart before checkout: \(error.localizedDescription)",
                component: "ApplePayManager")
            paymentResult = .failure("Unable to sync cart. Please try again.")
            isProcessing = false
            return
        }

        // Resolve checkoutId: explicit param > sponsor cart's checkoutId >
        // newly created (per-sponsor or legacy depending on sponsorId).
        let sponsorCachedCheckoutId = sponsorId.flatMap { cartManager.sponsorCart(forSponsorId: $0)?.checkoutId }
        let resolvedCheckoutId = (checkoutId ?? sponsorCachedCheckoutId)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedCheckoutId: String?
        if let resolvedCheckoutId, !resolvedCheckoutId.isEmpty {
            selectedCheckoutId = resolvedCheckoutId
        } else if let sid = sponsorId {
            selectedCheckoutId = await cartManager.createCheckout(forSponsor: sid)
        } else {
            selectedCheckoutId = await cartManager.createCheckout()
        }

        guard let checkoutId = selectedCheckoutId, !checkoutId.isEmpty else {
            paymentResult = .failure("No active checkout session. Please try again.")
            isProcessing = false
            return
        }

        pendingCheckoutId = checkoutId

        guard let runtimeBackendStripeKey = await resolveBackendStripeKey(
            checkoutId: checkoutId,
            cartManager: cartManager
        ) else {
            paymentResult = .failure("Missing backend Stripe credentials")
            isProcessing = false
            return
        }
        pendingPublishableKey = runtimeBackendStripeKey
        STPAPIClient.shared.publishableKey = runtimeBackendStripeKey

        guard !merchantIdentifier.isEmpty else {
            paymentResult = .failure("Payment configuration error")
            isProcessing = false
            return
        }

        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantIdentifier
        request.supportedNetworks = supportedNetworks
        request.merchantCapabilities = [.capability3DS, .capabilityCredit, .capabilityDebit]
        request.countryCode = normalizedCountryCode(cartManager.country)
        request.currencyCode = normalizedCurrencyCode(cartManager.currency)
        request.requiredShippingContactFields = [.postalAddress, .name, .emailAddress]
        request.requiredBillingContactFields = [.postalAddress, .name]
        request.paymentSummaryItems = buildSummaryItems(
            cartManager: cartManager,
            standaloneProductName: productName,
            standaloneAmount: amount
        )

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        VioLogger.info("Presenting Apple Pay sheet", component: logComponent)
        let presented = await controller.present()
        if !presented {
            VioLogger.error("Failed to present PKPaymentAuthorizationController", component: logComponent)
            await diagnoseMerchantIdentifierIssues()
            self.paymentResult = .failure("Apple Pay is not properly configured for this app. Please contact support.")
            self.isProcessing = false
        }
    }

    /// Internal helper to tokenize and confirm with backend
    private func tokenizeAndConfirm(payment: PKPayment, cartManager: CartManager) async -> Bool {
        var checkoutId = pendingCheckoutId
        
        // Final fallback if pendingCheckoutId was missed
        if checkoutId == nil {
            checkoutId = cartManager.checkoutId
        }

        guard let finalId = checkoutId else {
            VioLogger.warning("❌ [ApplePayManager] No checkoutId found! Cannot call confirm mutation.", component: "ApplePayManager")
            paymentResult = .failure("No active checkout session. Please try again.")
            return false
        }

        // Validate Stripe configuration before attempting tokenization
        guard let publishableKey = STPAPIClient.shared.publishableKey, !publishableKey.isEmpty else {
            VioLogger.error("Stripe key missing at tokenization stage", component: logComponent)
            paymentResult = .failure("Missing backend Stripe credentials")
            return false
        }

        VioLogger.debug(
            "Tokenize start merchant=\(merchantIdentifier) publishableKey=\(maskedStripeKey(publishableKey)) network=\(payment.token.paymentMethod.network?.rawValue ?? "unknown") paymentDataBytes=\(payment.token.paymentData.count)",
            component: logComponent
        )
        if payment.token.paymentData.isEmpty {
            // In some Apple Pay test/simulator flows, `paymentData` can be empty while
            // Stripe still produces a valid test token (`tok_*`). Do not hard-fail here.
            VioLogger.warning("Payment token data is empty; continuing with Stripe tokenization", component: logComponent)
        }

        // 1. Tokenize with Stripe
        let stripeToken: String
        do {
            let token: STPToken = try await withCheckedThrowingContinuation { continuation in
                STPAPIClient.shared.createToken(with: payment) { token, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let token = token {
                        continuation.resume(returning: token)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ApplePayManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown Stripe error"]))
                    }
                }
            }
            stripeToken = token.tokenId
            VioLogger.info("Tokenize success token=\(maskedToken(stripeToken))", component: logComponent)
        } catch {
            let nsError = error as NSError
            VioLogger.error(
                "Tokenize failure domain=\(nsError.domain) code=\(nsError.code) requestId=\((nsError.userInfo["com.stripe.lib:StripeRequestIDKey"] as? String) ?? "-") message=\(error.localizedDescription)",
                component: logComponent
            )
            let errorMessage: String
            if nsError.domain == "com.stripe.lib" && nsError.code == 50 {
                errorMessage = "Apple Pay is not properly configured. Please contact support."
            } else if nsError.localizedDescription.contains("merchant") {
                errorMessage = "Merchant configuration error. Please contact support."
            } else if nsError.localizedDescription.contains("decrypt") {
                errorMessage = "Apple Pay certificate error. Please contact support."
            } else {
                errorMessage = "Payment verification failed. Please try again."
            }
            
            paymentResult = .failure(errorMessage)
            return false
        }

        // 2. Prepare shipping address
        var shippingAddressInput: ApplePayAddressInputDto? = nil
        if let contact = capturedContact, let addr = contact.postalAddress {
            shippingAddressInput = ApplePayAddressInputDto(
                firstName: contact.name?.givenName,
                lastName: contact.name?.familyName,
                address1: addr.street,
                city: addr.city,
                province: addr.state,
                zip: addr.postalCode,
                country: addr.isoCountryCode,
                countryCode: addr.isoCountryCode
            )
        }

        // 3. Confirm with backend
        do {
            cartManager.syncSdkCredentials()
            VioLogger.debug(
                "applePayConfirm request checkoutId=\(finalId) token=\(maskedToken(stripeToken)) shippingPresent=\(shippingAddressInput != nil) sponsorId=\(pendingSponsorId.map(String.init) ?? "-")",
                component: logComponent
            )
            // Q4 L3: route through sponsor's SDK when pendingSponsorId set.
            let activeSdk = sdkForActivePayment(cartManager)
            let confirmDto = try await activeSdk.payment.applePayConfirm(
                checkoutId: finalId,
                applePayToken: stripeToken,
                email: capturedContact?.emailAddress,
                shippingAddress: shippingAddressInput
            )
            VioLogger.debug("applePayConfirm response status=\(confirmDto.status ?? "nil")", component: logComponent)

            let normalizedStatus = normalizedPaymentStatus(confirmDto.status)
            if normalizedStatus == "success" {
                VioLogger.success("applePayConfirm success orderId=\(confirmDto.orderId ?? "—")", component: logComponent)
                paymentResult = .success
                await cartManager.resetCartAndCreateNew()
                return true
            } else if normalizedStatus == "processing" || normalizedStatus == "pending" {
                VioLogger.warning("applePayConfirm pending status=\(confirmDto.status ?? "UNKNOWN")", component: logComponent)
                paymentResult = .failure("Payment is still processing. Please verify the order status.")
                return false
            } else {
                VioLogger.warning("applePayConfirm non-success status=\(confirmDto.status ?? "UNKNOWN")", component: logComponent)
                paymentResult = .failure("Payment failed: \(confirmDto.status ?? "unknown error")")
                return false
            }
        } catch {
            VioLogger.error("applePayConfirm GraphQL error: \(error.localizedDescription)", component: logComponent)
            paymentResult = .failure(error.localizedDescription)
            return false
        }
    }
    
    /// Diagnoses merchant identifier configuration issues
    private func diagnoseMerchantIdentifierIssues() async {
        guard isDebugBuild else { return }
        VioLogger.warning("Merchant identifier diagnostics started", component: logComponent)
        VioLogger.debug(
            "Current merchant configuration: merchantId=\(merchantIdentifier) build=\(isDebugBuild ? "DEBUG" : "RELEASE")",
            component: logComponent
        )
        
        VioLogger.debug("Running entitlement check", component: logComponent)
        // Check if we can create a payment request (this will validate entitlements)
        let testRequest = PKPaymentRequest()
        testRequest.merchantIdentifier = merchantIdentifier
        testRequest.supportedNetworks = [.visa] // Minimal network for testing
        testRequest.merchantCapabilities = [.capability3DS]
        testRequest.countryCode = "US"
        testRequest.currencyCode = "USD"
        testRequest.paymentSummaryItems = [PKPaymentSummaryItem(label: "Test", amount: NSDecimalNumber(value: 1.0))]
        
        let canAuthorize = PKPaymentAuthorizationController.canMakePayments(usingNetworks: [.visa])
        VioLogger.debug("Entitlement check canAuthorize=\(canAuthorize)", component: logComponent)
        VioLogger.warning(
            "Likely missing Apple Pay entitlement for merchantId=\(merchantIdentifier). Verify Signing & Capabilities and Apple Developer merchant setup.",
            component: logComponent
        )
        
        // Try to suggest alternative merchant IDs based on bundle identifier
        if let bundleId = Bundle.main.bundleIdentifier {
            let suggestedMerchant = "merchant.\(bundleId)"
            VioLogger.debug("Suggested merchant identifier based on bundle: \(suggestedMerchant)", component: logComponent)
        }
    }

    private func isValidAppleMerchantIdentifier(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("merchant.") && trimmed.count > "merchant.".count
    }

    private func maskedStripeKey(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return "nil" }
        return "\(key.prefix(14))...\(key.suffix(4))"
    }

    private func maskedToken(_ token: String) -> String {
        guard token.count > 12 else { return token }
        return "\(token.prefix(8))...\(token.suffix(4))"
    }

    private func normalizedPaymentStatus(_ status: String?) -> String {
        status?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func normalizedCountryCode(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.count == 2 ? trimmed : "US"
    }

    private func normalizedCurrencyCode(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.count == 3 ? trimmed : "USD"
    }

    private func resolveBackendStripeKey(checkoutId: String, cartManager: CartManager) async -> String? {
        if let keyFromInit = await extractStripeKeyFromApplePayInit(
            checkoutId: checkoutId,
            cartManager: cartManager
        ) {
            return keyFromInit
        }

        // Q4 L3: route through sponsor's SDK when pendingSponsorId set.
        let activeSdk = sdkForActivePayment(cartManager)
        for mode in VioRuntimeRetryPolicy.applePayStripeIntentReturnEphemeralKeyModes {
            do {
                let intent = try await activeSdk.payment.stripeIntent(
                    checkoutId: checkoutId,
                    returnEphemeralKey: mode
                )
                let key = intent.publishableKey.trimmingCharacters(in: .whitespacesAndNewlines)
                if !key.isEmpty {
                    return key
                }
            } catch {
                let modeLabel = mode.map(String.init) ?? "nil"
                VioLogger.warning(
                    "Apple Pay stripeIntent failed mode=\(modeLabel): \(error.localizedDescription)",
                    component: "ApplePayManager")
            }
        }
        return nil
    }

    private func extractStripeKeyFromApplePayInit(
        checkoutId: String,
        cartManager: CartManager
    ) async -> String? {
        do {
            // Q4 L3: route through sponsor's SDK when pendingSponsorId set.
            let activeSdk = sdkForActivePayment(cartManager)
            let initDto = try await activeSdk.payment.applePayInit(checkoutId: checkoutId)
            let backendValue = initDto.gatewayMerchantId.trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidAppleMerchantIdentifier(backendValue) {
                merchantIdentifier = backendValue
                return nil
            }
            if backendValue.hasPrefix("pk_") {
                return backendValue
            }
            return nil
        } catch {
            VioLogger.warning(
                "Apple Pay init failed before Stripe key resolution: \(error.localizedDescription)",
                component: "ApplePayManager")
            return nil
        }
    }
    
    // MARK: - Summary Item Helpers
    
    private func buildSummaryItems(
        cartManager: CartManager,
        standaloneProductName: String? = nil,
        standaloneAmount: Double? = nil
    ) -> [PKPaymentSummaryItem] {
        let merchantName = VioConfiguration.shared.brandConfiguration.name
        if cartManager.items.isEmpty,
            let standaloneProductName,
            let standaloneAmount
        {
            let amount = NSDecimalNumber(value: standaloneAmount)
            return [
                PKPaymentSummaryItem(label: standaloneProductName, amount: amount),
                PKPaymentSummaryItem(label: merchantName, amount: amount, type: .final)
            ]
        }

        var summaryItems: [PKPaymentSummaryItem] = []
        
        // Add items
        for item in cartManager.items {
            let label = "\(item.quantity)x \(item.title)"
            let amount = NSDecimalNumber(value: item.price * Double(item.quantity))
            summaryItems.append(PKPaymentSummaryItem(label: label, amount: amount))
        }
        
        // Add shipping if selected
        let shippingTotal = cartManager.shippingTotal
        if shippingTotal > 0 {
            summaryItems.append(PKPaymentSummaryItem(label: "Shipping", amount: NSDecimalNumber(value: shippingTotal)))
        }
        
        // Add grand total
        let total = NSDecimalNumber(value: cartManager.cartTotal + shippingTotal)
        summaryItems.append(PKPaymentSummaryItem(label: merchantName, amount: total, type: .final))
        
        return summaryItems
    }
}

extension ApplePayManager: PKPaymentAuthorizationControllerDelegate {

    public func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didSelectShippingContact contact: PKContact,
        handler completion: @escaping (PKPaymentRequestShippingContactUpdate) -> Void
    ) {
        Task { @MainActor in
            guard let cartManager = self.pendingCartManager else {
                completion(PKPaymentRequestShippingContactUpdate(errors: nil, paymentSummaryItems: [], shippingMethods: []))
                return
            }
            
            // 1. Update cart country to get regional shipping options
            if let countryCode = contact.postalAddress?.isoCountryCode {
                VioLogger.debug("Shipping address changed to \(countryCode); updating cart", component: "ApplePayManager")
                _ = try? await cartManager.sdk.cart.update(cart_id: cartManager.cartId ?? "", shipping_country: countryCode)
                _ = await cartManager.refreshShippingOptions()
            }
            
            // 2. Fetch shipping methods from the first item (Vio currently handles shipping per item)
            // For Apple Pay, we present the options of the first item as the available methods for the whole order
            let shippingMethods: [PKShippingMethod] = cartManager.items.first?.availableShippings.map { option in
                let method = PKShippingMethod(label: option.name, amount: NSDecimalNumber(value: option.amount))
                method.identifier = option.id
                method.detail = option.description
                return method
            } ?? []
            
            // 3. Update summary items
            let summaryItems = buildSummaryItems(cartManager: cartManager)
            
            completion(PKPaymentRequestShippingContactUpdate(
                errors: nil,
                paymentSummaryItems: summaryItems,
                shippingMethods: shippingMethods
            ))
        }
    }

    public func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didSelectShippingMethod shippingMethod: PKShippingMethod,
        handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void
    ) {
        Task { @MainActor in
            guard let cartManager = self.pendingCartManager, let optionId = shippingMethod.identifier else {
                completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: []))
                return
            }
            
            VioLogger.debug("Shipping method selected: \(shippingMethod.label) (\(optionId))", component: "ApplePayManager")
            
            // Apply this shipping option to all items in the cart (Standard Apple Pay behavior)
            for item in cartManager.items {
                cartManager.setShippingOption(for: item.id, optionId: optionId)
            }
            
            // Recalculate totals
            let summaryItems = buildSummaryItems(cartManager: cartManager)
            completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: summaryItems))
        }
    }

    public func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        capturedContact = payment.shippingContact
        Task { @MainActor in
            guard let cartManager = self.pendingCartManager else {
                VioLogger.error("No CartManager available in delegate", component: "ApplePayManager")
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
                return
            }
            
            // Sync final shipping selections to backend before confirming
            _ = await cartManager.applyCheapestShippingPerSupplier() // This actually applies all PENDING selections
            
            // Use the tokenization helper
            let success = await self.tokenizeAndConfirm(payment: payment, cartManager: cartManager)
            if success {
                completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            } else {
                completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            }
        }
    }

    public func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss {
            Task { @MainActor in
                self.isProcessing = false
                if self.paymentResult == nil {
                    self.paymentResult = .cancelled
                }
            }
        }
    }
}
#endif
