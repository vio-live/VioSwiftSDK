import Foundation
import VioCore
import SwiftUI

public protocol CartManagingSDK {
    var cart: CartRepository { get }
    var product: ProductRepository { get }
    var checkout: CheckoutRepository { get }
    var payment: PaymentRepository { get }
    var discount: DiscountRepository { get }
    var market: MarketRepository { get }
}

extension SdkClient: CartManagingSDK {
    public var product: ProductRepository { channel.product }
}

@MainActor
public class CartManager: ObservableObject {

    @Published public var items: [CartItem] = []
    @Published public var isCheckoutPresented = false
    @Published public var isLoading = false
    @Published public var cartTotal: Double = 0.0
    @Published public var currency: String = "USD"
    @Published public var country: String = "US"
    @Published public var errorMessage: String?
    @Published public var cartId: String?
    @Published public var checkoutId: String?
    @Published public var lastDiscountCode: String?
    @Published public var lastDiscountId: Int?
    @Published public var products: [Product] = []
    @Published public var isProductsLoading = false
    @Published public var productsErrorMessage: String?
    @Published public var shippingTotal: Double = 0.0
    @Published public var shippingCurrency: String = "USD"
    @Published public var markets: [Market] = []
    @Published public var selectedMarket: Market?
    @Published public var currencySymbol: String = "$"
    @Published public var phoneCode: String = "+1"
    @Published public var flagURL: String?

    /// Q4 L3 (2026-04-30): per-sponsor carts, keyed by `sponsors.id`.
    ///
    /// Source of truth for multi-sponsor stores. The flat `@Published`
    /// properties above (`items`, `cartTotal`, etc.) remain for back-
    /// compat — they're aggregated views computed from `cartsBySponsor`
    /// after every mutation (see `syncFlatPublishersFromSponsorCarts()`).
    ///
    /// Empty until the first product is added with a `sponsorId`. Single-
    /// sponsor placements that call `addProduct(_:variant:quantity:)` (no
    /// sponsorId) fall back to the campaign's primary sponsor — see
    /// `CartModule.resolveSponsorIdForFlatCallers()`.
    @Published public var cartsBySponsor: [Int: CartManager.SponsorCart] = [:]

    /// Q4 L4 (2026-05-06): the sponsor whose cart the user is currently
    /// checking out. Set by `VCheckoutOverlay.enterSponsorCheckoutScope`
    /// when the user taps "Checkout" on a sponsor section; cleared on
    /// success / cancel via `exitSponsorCheckoutScope`.
    ///
    /// **Mirroring strategy**: while non-nil, the flat legacy fields
    /// (`items`, `cartTotal`, `cartId`, `checkoutId`, `currency`,
    /// `country`, `shippingTotal`, `shippingCurrency`) are mirrored
    /// from the sponsor's cart so the legacy step views in
    /// `mainContent` render the right data without per-step sponsor
    /// branching. The original legacy values are saved in
    /// `_legacySnapshotForCheckoutScope` and restored on exit.
    ///
    /// Payment handler calls inside the scope still need to receive
    /// `sponsorId: activeCheckoutSponsorId` explicitly so they route
    /// through the sponsor's Commerce SDK (the mirror only handles the
    /// UI-side read; routing is decided in `resolvePaymentTarget`).
    @Published public var activeCheckoutSponsorId: Int?

    /// Snapshot of the flat legacy cart state taken when entering a
    /// sponsor checkout scope, restored on exit so any pre-existing
    /// legacy single-cart state survives a sponsor checkout. Internal
    /// — only `enterSponsorCheckoutScope` / `exitSponsorCheckoutScope`
    /// touch this.
    internal struct LegacySnapshotForCheckoutScope {
        var items: [CartItem]
        var cartTotal: Double
        var cartId: String?
        var checkoutId: String?
        var currency: String
        var country: String
        var shippingTotal: Double
        var shippingCurrency: String
        var lastDiscountCode: String?
        var lastDiscountId: Int?
    }
    internal var _legacySnapshotForCheckoutScope: LegacySnapshotForCheckoutScope?

    /// Q4 L4: enters a per-sponsor checkout scope. Mirrors the sponsor
    /// cart's data into the flat legacy fields so the existing
    /// `VCheckoutOverlay.mainContent` step views render against the
    /// sponsor's items/totals/checkoutId without modification.
    /// Idempotent: calling twice with the same sponsorId is a no-op.
    public func enterSponsorCheckoutScope(_ sponsorId: Int) {
        guard let cart = cartsBySponsor[sponsorId] else {
            VioLogger.warning("enterSponsorCheckoutScope: no cart for sponsor \(sponsorId)", component: "CartManager")
            return
        }
        // If we're already scoped to this sponsor, nothing to do.
        if activeCheckoutSponsorId == sponsorId { return }
        // If we're scoped to a different sponsor, exit first.
        if activeCheckoutSponsorId != nil {
            exitSponsorCheckoutScope(syncBackToSponsor: false)
        }
        // Snapshot the legacy state once.
        _legacySnapshotForCheckoutScope = LegacySnapshotForCheckoutScope(
            items: items,
            cartTotal: cartTotal,
            cartId: cartId,
            checkoutId: checkoutId,
            currency: currency,
            country: country,
            shippingTotal: shippingTotal,
            shippingCurrency: shippingCurrency,
            lastDiscountCode: lastDiscountCode,
            lastDiscountId: lastDiscountId
        )
        // Mirror sponsor cart into the flat legacy fields.
        items = cart.items
        cartTotal = cart.subtotal
        cartId = cart.cartId
        checkoutId = cart.checkoutId
        currency = cart.currency
        country = cart.country
        shippingTotal = cart.shippingTotal
        shippingCurrency = cart.shippingCurrency
        lastDiscountCode = cart.lastDiscountCode
        lastDiscountId = cart.lastDiscountId
        activeCheckoutSponsorId = sponsorId
        print("🟣 [Q4-DIAG enter-checkout-scope] sponsorId=\(sponsorId) cartId=\(cart.cartId ?? "nil") checkoutId=\(cart.checkoutId ?? "nil") items=\(cart.items.count)")
    }

    /// Q4 L4: exits a per-sponsor checkout scope. Restores the flat
    /// legacy fields from the snapshot. Pass `syncBackToSponsor: true`
    /// when the in-scope mutations (qty edits, discount applies, etc.)
    /// should be persisted into the sponsor cart before exiting (true
    /// for cancel paths so the user doesn't lose changes); pass false
    /// for success paths where the sponsor cart has already been
    /// cleared and any flat-field state is throw-away.
    public func exitSponsorCheckoutScope(syncBackToSponsor: Bool = true) {
        guard let sid = activeCheckoutSponsorId else { return }
        if syncBackToSponsor, var cart = cartsBySponsor[sid] {
            cart.items = items
            cart.subtotal = cartTotal
            cart.cartId = cartId
            cart.checkoutId = checkoutId
            cart.currency = currency
            cart.country = country
            cart.shippingTotal = shippingTotal
            cart.shippingCurrency = shippingCurrency
            cart.lastDiscountCode = lastDiscountCode
            cart.lastDiscountId = lastDiscountId
            cartsBySponsor[sid] = cart
        }
        if let s = _legacySnapshotForCheckoutScope {
            items = s.items
            cartTotal = s.cartTotal
            cartId = s.cartId
            checkoutId = s.checkoutId
            currency = s.currency
            country = s.country
            shippingTotal = s.shippingTotal
            shippingCurrency = s.shippingCurrency
            lastDiscountCode = s.lastDiscountCode
            lastDiscountId = s.lastDiscountId
        }
        _legacySnapshotForCheckoutScope = nil
        activeCheckoutSponsorId = nil
        print("🟣 [Q4-DIAG exit-checkout-scope] sponsorId=\(sid) syncBack=\(syncBackToSponsor)")
    }

    /// Q4 L4: items the active checkout is paying for. Returns the
    /// sponsor cart's items when `activeCheckoutSponsorId` is set,
    /// otherwise the legacy flat `items`. Used by the step views in
    /// `VCheckoutOverlay.mainContent` so they don't need explicit
    /// sponsor branching.
    public var activeCheckoutItems: [CartItem] {
        if let sid = activeCheckoutSponsorId, let cart = cartsBySponsor[sid] {
            return cart.items
        }
        return items
    }

    /// Q4 L4: subtotal scoped to the active checkout. Sponsor cart's
    /// subtotal when scoped, else legacy `cartTotal`.
    public var activeCheckoutSubtotal: Double {
        if let sid = activeCheckoutSponsorId, let cart = cartsBySponsor[sid] {
            return cart.subtotal
        }
        return cartTotal
    }

    /// Q4 L4: shipping total scoped to the active checkout.
    public var activeCheckoutShippingTotal: Double {
        if let sid = activeCheckoutSponsorId, let cart = cartsBySponsor[sid] {
            return cart.shippingTotal
        }
        return shippingTotal
    }

    /// Q4 L4: currency scoped to the active checkout (per-sponsor when
    /// scoped, falls back to legacy `currency`).
    public var activeCheckoutCurrency: String {
        if let sid = activeCheckoutSponsorId, let cart = cartsBySponsor[sid] {
            return cart.currency
        }
        return currency
    }

    /// Q4 L4: shipping country scoped to the active checkout. The
    /// legacy step views read this when building the shipping address
    /// for `applePayConfirm`, `klarnaNativeInit`, etc.
    public var activeCheckoutCountry: String {
        if let sid = activeCheckoutSponsorId, let cart = cartsBySponsor[sid] {
            return cart.country
        }
        return country
    }

    /// Q4 L4: checkoutId scoped to the active checkout. Used by the
    /// legacy step views' payment handler calls so the right Commerce
    /// checkout receives the operation. When the active sponsor cart
    /// doesn't have a checkoutId yet, callers fall back to the
    /// per-sponsor `createCheckout(forSponsor:)` (which the
    /// `resolvePaymentTarget` helper in PaymentManager handles
    /// transparently when given `sponsorId`).
    public var activeCheckoutCheckoutId: String? {
        if let sid = activeCheckoutSponsorId, let cart = cartsBySponsor[sid] {
            return cart.checkoutId
        }
        return checkoutId
    }

    internal var currentCartId: String?
    internal var pendingShippingSelections: [String: CartItem.ShippingOption] = [:]
    internal var didLoadMarkets = false
    internal var activeProductRequestID: UUID?
    internal var lastLoadedProductCurrency: String?
    internal var lastLoadedProductCountry: String?
    private var bootstrapObserver: NSObjectProtocol?

    internal var sdk: CartManagingSDK

    public init(
        sdk: CartManagingSDK? = nil,
        configuration: VioConfiguration = .shared,
        autoBootstrap: Bool = true
    ) {
        if let provided = sdk {
            self.sdk = provided
        } else {
            do {
                let sharedClient = try CommerceSdkClientProvider.shared.client(configuration: configuration)
                VioLogger.debug(
                    "Initializing shared SDK Client - Base URL: \(sharedClient.baseUrl), API Key: \(sharedClient.apiKey.prefix(8))...",
                    component: "CartManager")
                self.sdk = sharedClient
            } catch {
                let baseURL = URL(string: configuration.environment.graphQLURL) ?? URL(string: "https://graph-ql-dev.vio.live/graphql")!
                let apiKey = configuration.apiKey.isEmpty ? "DEMO_KEY" : configuration.apiKey
                VioLogger.warning(
                    "Falling back to direct SDK client init due to provider error: \(error.localizedDescription)",
                    component: "CartManager")
                self.sdk = SdkClient(baseUrl: baseURL, apiKey: apiKey)
            }
        }

        let fallback = configuration.marketConfiguration
        let fallbackMarket = Market(
            code: fallback.countryCode,
            name: fallback.countryName,
            officialName: fallback.countryName,
            flagURL: fallback.flagURL,
            phoneCode: fallback.phoneCode,
            currencyCode: fallback.currencyCode,
            currencySymbol: fallback.currencySymbol
        )

        markets = [fallbackMarket]
        selectedMarket = fallbackMarket
        country = fallback.countryCode
        currency = fallback.currencyCode
        currencySymbol = fallback.currencySymbol
        phoneCode = fallback.phoneCode
        flagURL = fallback.flagURL
        shippingCurrency = fallback.currencyCode

        if autoBootstrap {
            Task { [currency, country] in
                // Check if SDK should be used before attempting operations
                guard VioConfiguration.shared.shouldUseSDK else {
                    VioLogger.warning("Skipping cart creation - SDK disabled (market not available)", component: "CartManager")
                    return
                }
                
                await CampaignManager.shared.ensureCommerceBootstrapApplied()
                self.syncSdkCredentials()
                VioLogger.debug("init → scheduling createCart(currency:\(currency), country:\(country))", component: "CartManager")
                await createCart(currency: currency, country: country)
                await loadMarketsIfNeeded()
            }
        }

        bootstrapObserver = NotificationCenter.default.addObserver(
            forName: .vioCommerceBootstrapDidApply,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncSdkCredentials()
            }
        }
    }

    deinit {
        if let observer = bootstrapObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Ensures the underlying SdkClient is using the latest credentials from VioConfiguration
    public func syncSdkCredentials() {
        guard let concreteSdk = sdk as? SdkClient else { return }
        let config = VioConfiguration.shared
        do {
            let sharedClient = try CommerceSdkClientProvider.shared.client(configuration: config)
            if concreteSdk !== sharedClient {
                let currentUrl = sharedClient.baseUrl
                let currentKey = sharedClient.apiKey
                if concreteSdk.baseUrl != currentUrl || concreteSdk.apiKey != currentKey {
                    VioLogger.debug("Syncing SDK credentials to resolved values...", component: "CartManager")
                    concreteSdk.updateCredentials(baseUrl: currentUrl, apiKey: currentKey)
                }
            }
        } catch {
            guard let currentUrl = URL(string: config.resolvedCommerceGraphQLURL) else {
                VioLogger.error("Invalid resolved commerce URL while syncing credentials", component: "CartManager")
                return
            }
            let currentKey = config.resolvedCommerceApiKey
            if concreteSdk.baseUrl != currentUrl || concreteSdk.apiKey != currentKey {
                VioLogger.debug("Syncing SDK credentials to resolved values...", component: "CartManager")
                concreteSdk.updateCredentials(baseUrl: currentUrl, apiKey: currentKey)
            }
        }
    }

    internal func isCommerceAuthFailure(_ error: Error) -> Bool {
        if let sdkError = error as? SdkException {
            let code = sdkError.code?.uppercased() ?? ""
            if code == "UNAUTHENTICATED" || code == "AUTHENTICATION_FAILED" {
                return true
            }
            if let status = sdkError.status, status == 401 || status == 403 {
                return true
            }
            let msg = sdkError.message.lowercased()
            return msg.contains("authentication failed") || msg.contains("unauthenticated")
        }
        let msg = error.localizedDescription.lowercased()
        return msg.contains("authentication failed") || msg.contains("unauthenticated")
    }

    public func showCheckout() {
        isCheckoutPresented = true
    }

    public func hideCheckout() {
        isCheckoutPresented = false
    }

    internal func iso8601String(from date: Date = Date()) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    internal func logRequest(_ action: String, payload: Any? = nil) {
        if let payload = payload {
            VioLogger.debug("REQUEST: \(action) - Payload: \(String(describing: payload))", component: "CartManager")
        } else {
            VioLogger.debug("REQUEST: \(action)", component: "CartManager")
        }
    }

    internal func logResponse(_ action: String, payload: Any? = nil) {
        if let payload = payload {
            VioLogger.debug("\(action) response: \(String(describing: payload))", component: "CartManager")
        } else {
            VioLogger.debug("\(action) response", component: "CartManager")
        }
    }

    internal func logError(_ action: String, error: Error) {
        VioLogger.error("ERROR: \(action) - Type: \(type(of: error)), Message: \(error.localizedDescription)", component: "CartManager")
    }

    public func getCheckoutStatus(_ checkoutId: String) async -> Bool {
        syncSdkCredentials()
        VioLogger.debug("getCheckoutStatus() with checkoutId: \(checkoutId)", component: "CartManager")

        do {
            let result: GetCheckoutDto = try await sdk.checkout.getById(checkout_id: checkoutId);
            VioLogger.debug("getCheckoutStatus() result: \(result)", component: "CartManager")

            // ✅ Here you validate if Vipps already paid
            if result.status == "SUCCESS" {
                VioLogger.success("Payment confirmed in backend", component: "CartManager")
                return true
            } else {
                VioLogger.debug("Still unpaid: \(result.status)", component: "CartManager")
                return false
            }

        } catch {
            logError("getCheckoutStatus", error: error)
            return false
        }
    }
}
