import Foundation
import VioCore
import VioDesignSystem

// MARK: - 🚧 Q4 L3 — PAUSED 2026-04-30 PM
//
// Status: paused mid-flight. Multi-sponsor cart UI (B1+B2) renders
// correctly and `cartsBySponsor` is populated correctly. Apple Pay flow
// **fails at applePayConfirm** with `[object Object]` from Commerce
// backend when routed through the sponsor's commerce_api_key (B4).
//
// KNOWN ISSUE — needs Commerce-side investigation before resuming:
//
//   1. Pre-B4 behavior (commit 8584e0d): Apple Pay confirm always used
//      cartManager.sdk (primary's apiKey = Elkjøp). Commerce returned
//      success and an order was created, BUT Stripe never received a
//      charge (suggesting Commerce processed against a primary-channel
//      cart that didn't actually contain the multi-sponsor items).
//
//   2. Post-B4 behavior (commit 3cf9a74): Apple Pay confirm uses the
//      sponsor's apiKey (e.g. XXL = KCXF10Y…). Commerce returns 500
//      "Payment Apple Pay not confirmed: [object Object]" — the
//      sponsor's channel doesn't process the charge end-to-end.
//
// Suspected root cause (needs verification with Alan / Commerce team):
//
//   - Sponsor channels (XXL #7, Torshov #4) may have the Apple Pay
//     flag enabled in Commerce dashboard but **lack a Stripe Connect
//     account linked**. Apple Pay flag and Stripe Connect linking are
//     two separate config items in Commerce; only the latter is what
//     `ConfirmPaymentApplePay.run` server-side actually exercises.
//   - Alternative: the merchant identifier `merchant.live.vio` may
//     not be approved on the sponsor's Stripe Connect account in the
//     Apple/Stripe setup.
//   - Alternative: products of XXL/Torshov may not exist in the
//     sponsor's own Reachu catalog (only in Elkjøp's primary catalog
//     where they are cross-listed for multi-sponsor stores).
//
// Path forward (NOT IMPLEMENTED YET — decision pending):
//
//   Path A — wait for Commerce config: each sponsor channel gets
//     Stripe Connect activated; B4 stays as-is and works.
//   Path B — rollback B4 routing: cart per-sponsor for UI only, Apple
//     Pay confirm always via primary aggregator (Vio merchant on Elkjøp's
//     Stripe Connect). Requires all multi-sponsor products to be
//     listed in primary's Reachu catalog. Server-side split to each
//     sponsor's account is Commerce's responsibility.
//   Path C — hybrid: per-sponsor cart creation but applePayConfirm
//     via primary apiKey targeting the sponsor's checkoutId. Likely
//     rejected by Commerce as cross-channel confirm.
//
// Last commits in this branch:
//   8584e0d  feat(q4-l3 B3): connect VProductDetailOverlay.addToCart
//            to sponsor-aware overload  ← LAST PARTIALLY-WORKING POINT
//   af12b84  feat(q4-l3 B2): VCheckoutOverlay dual-mode
//   9b0f67b  feat(q4-l3 B1): SponsorCheckoutSection
//   5c3c110  feat(q4-l3 A3): remove/update/clear per-sponsor
//   ff5eeb7  feat(q4-l3 A2): addProduct(sponsorId:) overload
//   e947030  feat(q4-l3 A1): SponsorCart struct + cartsBySponsor
//   3cf9a74  fix(q4-l3 B4): route Apple Pay through sponsor SDK
//            ← RESULTS IN [object Object] FROM COMMERCE
//
// To resume: confirm with Alan whether sponsor channels can process
// applePayConfirm independently. If yes → keep B4. If no → revert B4
// and implement Path B (cart unified at primary, UI multi-sponsor only).

// MARK: - Q4 Layer 3: per-sponsor cart routing
//
// This file lives next to `CartModule.swift` but stays compartmentalised so
// the legacy single-cart path is never accidentally mutated. The legacy
// public surface (`addProduct(_:variant:quantity:)`, `removeItem`,
// `updateQuantity`, `clearCart`, `currentCartId`, `items`, `cartTotal`,
// etc.) keeps working exactly as before — Q4 L3 only **adds** a parallel
// per-sponsor path on top.
//
// Lifecycle of `cartsBySponsor`:
//   1. addProduct(_:variant:quantity:sponsorId:) gets/creates a SponsorCart
//      for `sponsorId`, resolves the per-sponsor `CartManagingSDK` via
//      `CommerceSdkClientProvider.client(forSponsorId:)`, ensures a Reachu
//      cart row exists for that sponsor's channel, and dispatches addItem
//      / updateItem to that channel.
//   2. The resulting `CartDto` is mapped into `CartItem`s and stored in
//      `cartsBySponsor[sponsorId]` (the legacy `items` / `cartTotal`
//      remain untouched here so single-sponsor callers keep working).
//   3. UI for multi-sponsor stores reads `cartsBySponsor` directly — see
//      `VCheckoutOverlay`'s SponsorCheckoutSection (Fase B).
//   4. Aggregate readers (`itemCountAcrossSponsors`,
//      `totalAcrossSponsors`) are exposed for cart-badge UIs that need
//      a single number.

@MainActor
extension CartManager {

    // MARK: - Public API

    /// Adds a product to the **sponsor's** cart, routing through that
    /// sponsor's Reachu Commerce channel. Use this from multi-sponsor
    /// stores where each item carries its own `sponsorId`.
    ///
    /// Behaves like `addProduct(_:variant:quantity:)` for the
    /// (single-sponsor, legacy) path, except writes go to
    /// `cartsBySponsor[sponsorId]` instead of the flat `items` /
    /// `currentCartId` properties.
    ///
    /// If the sponsor has no `commerce_api_key` configured (visual-only
    /// sponsor) the call is a no-op + warning — no fallback to a global
    /// or primary key (per the v2 rule "no hardcoded apiKeys").
    public func addProduct(
        _ product: Product,
        variant: VioCore.Variant? = nil,
        quantity: Int = 1,
        sponsorId: Int
    ) async {
        // 1. Resolve sponsor's SDK client (per-sponsor commerce key).
        guard let sponsorSdk = resolveSponsorSdk(forSponsorId: sponsorId) else {
            VioLogger.warning(
                "addProduct(sponsorId:\(sponsorId)) skipped — sponsor has no commerce key (visual-only or unknown sponsor)",
                component: "CartModule"
            )
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 2. Get or create the SponsorCart skeleton.
        var sponsorCart = cartsBySponsor[sponsorId] ?? SponsorCart(
            sponsorId: sponsorId,
            currency: currency,
            country: country,
            shippingCurrency: shippingCurrency
        )

        // 3. Ensure a Reachu cart row exists in the sponsor's channel.
        guard let cid = await ensureSponsorCartId(
            for: &sponsorCart,
            sdk: sponsorSdk
        ), !cid.isEmpty else {
            VioLogger.error(
                "addProduct(sponsorId:\(sponsorId)) — could not create Reachu cart in sponsor's channel",
                component: "CartModule"
            )
            cartsBySponsor[sponsorId] = sponsorCart
            return
        }

        // 4. Resolve target variant + check if the line already exists.
        let selectedVariant = variant ?? product.variants.first
        let selectedVariantId = selectedVariant?.id
        let existingItem = sponsorCart.items.first {
            $0.productId == product.id && $0.variantId == selectedVariantId
        }

        // 5. Dispatch to Reachu Commerce GraphQL via the sponsor's SDK.
        do {
            let dto: CartDto
            if let existing = existingItem {
                let newQuantity = existing.quantity + quantity
                logRequest(
                    "sdk.cart.updateItem (sponsor=\(sponsorId))",
                    payload: [
                        "cart_id": cid,
                        "cart_item_id": existing.id,
                        "quantity": newQuantity
                    ]
                )
                dto = try await sponsorSdk.cart.updateItem(
                    cart_id: cid,
                    cart_item_id: existing.id,
                    shipping_id: nil,
                    quantity: newQuantity
                )
            } else {
                let variantIdInt = selectedVariantId.flatMap { Int($0) }
                let line = LineItemInput(
                    productId: product.id,
                    variantId: variantIdInt,
                    quantity: quantity,
                    priceData: nil
                )
                logRequest(
                    "sdk.cart.addItem (sponsor=\(sponsorId))",
                    payload: [
                        "cart_id": cid,
                        "productId": product.id,
                        "variantId": variantIdInt as Any,
                        "quantity": quantity
                    ]
                )
                dto = try await sponsorSdk.cart.addItem(
                    cart_id: cid,
                    line_items: [line]
                )
            }
            logResponse(
                "sdk.cart.addItem/updateItem (sponsor=\(sponsorId))",
                payload: ["cartId": dto.cartId, "itemCount": dto.lineItems.count]
            )
            syncSponsorCart(&sponsorCart, from: dto)
            cartsBySponsor[sponsorId] = sponsorCart
            // Q4 L3 B6 (2026-05-04): auto-select first available shipping
            // for items without one. Legacy VCheckoutOverlay has a UI
            // (`shippingOptionsSelectionView`) for the user to pick;
            // SponsorCheckoutSection doesn't expose one yet, so we
            // server-select to keep the cart checkout-ready. Without
            // shipping_id per line item, Commerce's `applePayConfirm`
            // returns the generic `[object Object]` error.
            await autoSelectFirstShipping(forSponsor: sponsorId, sdk: sponsorSdk)
            ToastManager.shared.showSuccess("Added \(product.title) to cart")
        } catch let error as SdkException {
            errorMessage = error.description
            logError("sdk.cart.update/addItem (sponsor=\(sponsorId))", error: error)
            VioLogger.error(
                "addProduct(sponsorId:\(sponsorId)) FAIL: \(error.description)",
                component: "CartModule"
            )
            addItemLocallyToSponsorCart(
                &sponsorCart,
                product: product,
                variant: selectedVariant,
                quantity: quantity
            )
            cartsBySponsor[sponsorId] = sponsorCart
            ToastManager.shared.showWarning("Using local cart for \(product.title) (sync error)")
        } catch {
            errorMessage = error.localizedDescription
            logError("sdk.cart.update/addItem (sponsor=\(sponsorId))", error: error)
            VioLogger.error(
                "addProduct(sponsorId:\(sponsorId)) FAIL: \(error.localizedDescription)",
                component: "CartModule"
            )
            addItemLocallyToSponsorCart(
                &sponsorCart,
                product: product,
                variant: selectedVariant,
                quantity: quantity
            )
            cartsBySponsor[sponsorId] = sponsorCart
            ToastManager.shared.showWarning("Added \(product.title) locally due to error")
        }
    }

    // MARK: - Remove / update / clear (per-sponsor)

    /// Removes an item from the sponsor's cart. The item must belong to
    /// that sponsor's cart — the call is a no-op + warning when the item
    /// id is not found in `cartsBySponsor[sponsorId]`.
    public func removeItem(_ item: CartItem, fromSponsor sponsorId: Int) async {
        guard var sponsorCart = cartsBySponsor[sponsorId] else {
            VioLogger.warning(
                "removeItem(fromSponsor:\(sponsorId)) — no cart exists for that sponsor",
                component: "CartModule"
            )
            return
        }
        guard sponsorCart.items.contains(where: { $0.id == item.id }) else {
            VioLogger.warning(
                "removeItem(fromSponsor:\(sponsorId)) — item \(item.id) not in this sponsor's cart",
                component: "CartModule"
            )
            return
        }
        guard let sponsorSdk = resolveSponsorSdk(forSponsorId: sponsorId) else {
            VioLogger.warning(
                "removeItem(fromSponsor:\(sponsorId)) skipped — no commerce key",
                component: "CartModule"
            )
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var didSyncFromServer = false
        if let cid = sponsorCart.cartId, !cid.isEmpty {
            do {
                logRequest(
                    "sdk.cart.deleteItem (sponsor=\(sponsorId))",
                    payload: ["cart_id": cid, "cart_item_id": item.id]
                )
                let dto = try await sponsorSdk.cart.deleteItem(
                    cart_id: cid,
                    cart_item_id: item.id
                )
                logResponse(
                    "sdk.cart.deleteItem (sponsor=\(sponsorId))",
                    payload: ["cartId": dto.cartId, "itemCount": dto.lineItems.count]
                )
                syncSponsorCart(&sponsorCart, from: dto)
                cartsBySponsor[sponsorId] = sponsorCart
                didSyncFromServer = true
            } catch let error as SdkException {
                errorMessage = error.description
                logError("sdk.cart.deleteItem (sponsor=\(sponsorId))", error: error)
                VioLogger.warning(
                    "SDK.deleteItem(sponsor=\(sponsorId)) failed: \(error.description)",
                    component: "CartModule"
                )
            } catch {
                errorMessage = error.localizedDescription
                logError("sdk.cart.deleteItem (sponsor=\(sponsorId))", error: error)
                VioLogger.warning(
                    "SDK.deleteItem(sponsor=\(sponsorId)) failed: \(error.localizedDescription)",
                    component: "CartModule"
                )
            }
        } else {
            VioLogger.info(
                "removeItem(fromSponsor:\(sponsorId)): skipped SDK call (no cartId yet)",
                component: "CartModule"
            )
        }

        if !didSyncFromServer {
            // Local fallback: remove the item from the sponsor cart
            // directly so the UI updates even when the SDK call failed.
            sponsorCart.items.removeAll { $0.id == item.id }
            sponsorCart.subtotal = sponsorCart.items.reduce(0.0) { total, it in
                total + (it.price * Double(it.quantity))
            }
            cartsBySponsor[sponsorId] = sponsorCart
        }
        ToastManager.shared.showInfo("Removed \(item.title) from cart")
    }

    /// Updates the quantity for an item in the sponsor's cart. When
    /// `newQuantity <= 0` the item is deleted (matches the legacy
    /// `updateQuantity(for:to:)` semantics). No-op if the item or sponsor
    /// cart is unknown.
    public func updateQuantity(
        for item: CartItem,
        to newQuantity: Int,
        fromSponsor sponsorId: Int
    ) async {
        guard var sponsorCart = cartsBySponsor[sponsorId] else {
            VioLogger.warning(
                "updateQuantity(fromSponsor:\(sponsorId)) — no cart for that sponsor",
                component: "CartModule"
            )
            return
        }
        guard sponsorCart.items.contains(where: { $0.id == item.id }) else {
            VioLogger.warning(
                "updateQuantity(fromSponsor:\(sponsorId)) — item \(item.id) not in this sponsor's cart",
                component: "CartModule"
            )
            return
        }
        guard let sponsorSdk = resolveSponsorSdk(forSponsorId: sponsorId) else {
            VioLogger.warning(
                "updateQuantity(fromSponsor:\(sponsorId)) skipped — no commerce key",
                component: "CartModule"
            )
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var didSyncFromServer = false
        if let cid = sponsorCart.cartId, !cid.isEmpty {
            do {
                let dto: CartDto
                if newQuantity <= 0 {
                    logRequest(
                        "sdk.cart.deleteItem (sponsor=\(sponsorId))",
                        payload: ["cart_id": cid, "cart_item_id": item.id]
                    )
                    dto = try await sponsorSdk.cart.deleteItem(
                        cart_id: cid,
                        cart_item_id: item.id
                    )
                } else {
                    logRequest(
                        "sdk.cart.updateItem (sponsor=\(sponsorId))",
                        payload: [
                            "cart_id": cid,
                            "cart_item_id": item.id,
                            "quantity": newQuantity
                        ]
                    )
                    dto = try await sponsorSdk.cart.updateItem(
                        cart_id: cid,
                        cart_item_id: item.id,
                        shipping_id: nil,
                        quantity: newQuantity
                    )
                }
                logResponse(
                    "sdk.cart.update/deleteItem (sponsor=\(sponsorId))",
                    payload: ["cartId": dto.cartId, "itemCount": dto.lineItems.count]
                )
                syncSponsorCart(&sponsorCart, from: dto)
                cartsBySponsor[sponsorId] = sponsorCart
                didSyncFromServer = true
            } catch let error as SdkException {
                errorMessage = error.description
                logError("sdk.cart.update/deleteItem (sponsor=\(sponsorId))", error: error)
            } catch {
                errorMessage = error.localizedDescription
                logError("sdk.cart.update/deleteItem (sponsor=\(sponsorId))", error: error)
            }
        }

        if !didSyncFromServer {
            // Local fallback: mutate the SponsorCart directly.
            if newQuantity <= 0 {
                sponsorCart.items.removeAll { $0.id == item.id }
            } else if let idx = sponsorCart.items.firstIndex(where: { $0.id == item.id }) {
                sponsorCart.items[idx].quantity = newQuantity
            }
            sponsorCart.subtotal = sponsorCart.items.reduce(0.0) { total, it in
                total + (it.price * Double(it.quantity))
            }
            cartsBySponsor[sponsorId] = sponsorCart
        }
    }

    /// Creates a Reachu Commerce Checkout for the sponsor's cart and
    /// stores the resulting `checkoutId` on the SponsorCart in
    /// `cartsBySponsor[sponsorId]`. Required before Apple Pay confirm —
    /// `sdk.payment.applePayConfirm(checkoutId:)` and
    /// `sdk.payment.stripeIntent(checkoutId:)` both need a checkoutId
    /// scoped to the same channel (the one matching the sponsor's
    /// commerce_api_key). Q4 L3 (2026-04-30) — analogous to the legacy
    /// `createCheckout()` but uses the sponsor's SDK client + sponsor cart id.
    @discardableResult
    public func createCheckout(forSponsor sponsorId: Int) async -> String? {
        guard var sponsorCart = cartsBySponsor[sponsorId] else {
            VioLogger.warning(
                "createCheckout(forSponsor:\(sponsorId)) — no cart for that sponsor",
                component: "CartModule"
            )
            return nil
        }
        guard let cid = sponsorCart.cartId, !cid.isEmpty else {
            VioLogger.warning(
                "createCheckout(forSponsor:\(sponsorId)) — sponsor cart has no cartId yet",
                component: "CartModule"
            )
            return nil
        }
        guard let sponsorSdk = resolveSponsorSdk(forSponsorId: sponsorId) else {
            return nil
        }

        VioLogger.debug(
            "createCheckout(forSponsor:\(sponsorId)) START cartId=\(cid)",
            component: "CartModule"
        )
        do {
            logRequest(
                "sdk.checkout.create (sponsor=\(sponsorId))",
                payload: ["cart_id": cid]
            )
            let dto = try await sponsorSdk.checkout.create(cart_id: cid)
            let chkId = extractCheckoutId(dto)
            sponsorCart.checkoutId = chkId
            cartsBySponsor[sponsorId] = sponsorCart
            logResponse(
                "sdk.checkout.create (sponsor=\(sponsorId))",
                payload: ["checkoutId": chkId as Any]
            )
            VioLogger.success(
                "createCheckout(forSponsor:\(sponsorId)) OK checkoutId=\(chkId ?? "nil")",
                component: "CartModule"
            )
            return chkId
        } catch {
            let msg = (error as? SdkException)?.description ?? error.localizedDescription
            logError("sdk.checkout.create (sponsor=\(sponsorId))", error: error)
            VioLogger.error(
                "createCheckout(forSponsor:\(sponsorId)) FAIL: \(msg)",
                component: "CartModule"
            )
            return nil
        }
    }

    /// Drops the entire cart for one sponsor, both server-side (best
    /// effort) and locally. Other sponsors' carts are untouched.
    public func clearCart(forSponsor sponsorId: Int) async {
        guard var sponsorCart = cartsBySponsor[sponsorId] else {
            return  // nothing to clear
        }
        let sponsorSdk = resolveSponsorSdk(forSponsorId: sponsorId)

        if let cid = sponsorCart.cartId, !cid.isEmpty, let sdk = sponsorSdk {
            do {
                logRequest(
                    "sdk.cart.delete (sponsor=\(sponsorId))",
                    payload: ["cart_id": cid]
                )
                _ = try await sdk.cart.delete(cart_id: cid)
                logResponse(
                    "sdk.cart.delete (sponsor=\(sponsorId))",
                    payload: ["cartId": cid]
                )
            } catch {
                VioLogger.warning(
                    "clearCart(sponsor=\(sponsorId)) — server delete failed; clearing locally only: \(error.localizedDescription)",
                    component: "CartModule"
                )
            }
        }

        sponsorCart.cartId = nil
        sponsorCart.checkoutId = nil
        sponsorCart.items = []
        sponsorCart.subtotal = 0
        sponsorCart.shippingTotal = 0
        sponsorCart.lastDiscountCode = nil
        sponsorCart.lastDiscountId = nil
        cartsBySponsor[sponsorId] = sponsorCart
    }

    /// Drops every per-sponsor cart in one shot. Useful after a checkout
    /// completes successfully across all sponsors, or as a "reset all"
    /// during error recovery. Iterates `cartsBySponsor` and calls
    /// `clearCart(forSponsor:)` for each.
    public func clearAllCarts() async {
        let sponsorIds = Array(cartsBySponsor.keys)
        for sponsorId in sponsorIds {
            await clearCart(forSponsor: sponsorId)
        }
        // Drop empty entries so cartsBySponsor stays clean for observers.
        cartsBySponsor = cartsBySponsor.filter { !$0.value.items.isEmpty || $0.value.cartId != nil }
    }

    // MARK: - Aggregate readers

    /// Sum of `itemCount` across every SponsorCart. Useful for cart-badge
    /// UIs that need a single number "how many items in total".
    ///
    /// Note: this **does not** include the legacy single-cart `items` —
    /// once Fase D migrates the demo to the multi-sponsor path the
    /// legacy `items` will mirror only the primary sponsor's cart, so
    /// they don't double-count.
    public var itemCountAcrossSponsors: Int {
        cartsBySponsor.values.reduce(0) { $0 + $1.itemCount }
    }

    /// Sum of `subtotal` across every SponsorCart. The currency is the
    /// **first sponsor cart's** currency — assumes the host app picks a
    /// single market across sponsors (true for TV2 NO today). When mixing
    /// markets the host must aggregate per cart manually.
    public var totalAcrossSponsors: Double {
        cartsBySponsor.values.reduce(0) { $0 + $1.subtotal }
    }

    /// Sum of `shippingTotal` across every SponsorCart. Same currency
    /// caveat as `totalAcrossSponsors`.
    public var shippingTotalAcrossSponsors: Double {
        cartsBySponsor.values.reduce(0) { $0 + $1.shippingTotal }
    }

    /// Returns the SponsorCart for `sponsorId`, or nil when no items have
    /// been added for that sponsor yet.
    public func sponsorCart(forSponsorId sponsorId: Int) -> SponsorCart? {
        cartsBySponsor[sponsorId]
    }

    // MARK: - Internal helpers

    /// Resolves the sponsor's per-channel SDK client. Returns nil if the
    /// sponsor has no `commerce_api_key` (visual-only sponsor) or is
    /// unknown to `VioConfiguration.shared` (subscribe response did not
    /// include them).
    internal func resolveSponsorSdk(forSponsorId sponsorId: Int) -> CartManagingSDK? {
        do {
            let sponsorClient = try CommerceSdkClientProvider.shared.client(
                forSponsorId: sponsorId,
                configuration: VioConfiguration.shared
            )
            // The provider's per-sponsor lookup falls back to the primary
            // when the sponsor lacks a key. For Q4 L3 we want strict
            // per-sponsor routing (no silent primary fallback in the
            // multi-sponsor path), so verify the resolved active sponsor
            // matches what we asked for.
            guard CommerceSdkClientProvider.shared.activeSponsorId == sponsorId else {
                return nil
            }
            return sponsorClient
        } catch {
            VioLogger.error(
                "resolveSponsorSdk(\(sponsorId)) failed: \(error.localizedDescription)",
                component: "CartModule"
            )
            return nil
        }
    }

    /// Ensures `sponsorCart.cartId` is set. Calls `Cart.create` against
    /// the sponsor's SDK if no cart row exists yet. Mutates `sponsorCart`
    /// in place. Returns the resolved cartId or nil on failure.
    internal func ensureSponsorCartId(
        for sponsorCart: inout SponsorCart,
        sdk: CartManagingSDK
    ) async -> String? {
        if let id = sponsorCart.cartId, !id.isEmpty {
            return id
        }
        let session = "ios-sp\(sponsorCart.sponsorId)-\(UUID().uuidString)"
        logRequest(
            "sdk.cart.create (sponsor=\(sponsorCart.sponsorId))",
            payload: [
                "session": session,
                "currency": sponsorCart.currency,
                "country": sponsorCart.country
            ]
        )
        do {
            let dto = try await sdk.cart.create(
                customer_session_id: session,
                currency: sponsorCart.currency,
                shippingCountry: sponsorCart.country
            )
            logResponse(
                "sdk.cart.create (sponsor=\(sponsorCart.sponsorId))",
                payload: ["cartId": dto.cartId]
            )
            sponsorCart.cartId = dto.cartId
            sponsorCart.currency = dto.currency
            sponsorCart.country = dto.shippingCountry ?? sponsorCart.country
            return dto.cartId
        } catch {
            logError(
                "sdk.cart.create (sponsor=\(sponsorCart.sponsorId))",
                error: error
            )
            VioLogger.error(
                "ensureSponsorCartId(\(sponsorCart.sponsorId)) FAIL: \(error.localizedDescription)",
                component: "CartModule"
            )
            return nil
        }
    }

    /// Hydrates a SponsorCart from a Reachu `CartDto`. Mirrors the
    /// mapping that the legacy `sync(from:)` does for the flat
    /// publishers; we duplicate it on purpose so changes to the legacy
    /// path don't accidentally mutate per-sponsor state, and vice
    /// versa. (Fase A4 / D may consolidate this into a shared helper
    /// once the multi-sponsor path is the canonical one.)
    internal func syncSponsorCart(
        _ sponsorCart: inout SponsorCart,
        from cart: CartDto
    ) {
        sponsorCart.cartId = cart.cartId
        sponsorCart.currency = cart.currency
        sponsorCart.country = cart.shippingCountry ?? sponsorCart.country

        let mapped: [CartItem] = cart.lineItems.map { line in
            let sortedImages = (line.image ?? []).sorted { lhs, rhs in
                let lOrder = lhs.order ?? 0
                let rOrder = rhs.order ?? 0
                return lOrder < rOrder
            }
            let imageUrl = sortedImages.first?.url

            let shipping = line.shipping
            let shippingCurrency = shipping?.price.currencyCode ?? cart.currency
            let availableShippings = (line.availableShippings ?? []).compactMap {
                option -> CartItem.ShippingOption? in
                guard let id = option.id, !id.isEmpty else { return nil }
                let amount: Double = option.price.amountInclTaxes ?? option.price.amount ?? 0.0
                let currency = option.price.currencyCode ?? cart.currency
                return CartItem.ShippingOption(
                    id: id,
                    name: option.name ?? "Shipping",
                    description: option.description,
                    amount: amount,
                    currency: currency
                )
            }

            let productPrice = line.price.amountInclTaxes ?? line.price.amount
            let shippingPrice: Double? = shipping?.price.amountInclTaxes ?? shipping?.price.amount

            return CartItem(
                id: line.id,
                productId: line.productId,
                variantId: line.variantId.map { String($0) },
                variantTitle: line.variantTitle,
                title: line.title ?? "",
                brand: line.brand,
                imageUrl: imageUrl,
                price: productPrice,
                currency: line.price.currencyCode,
                quantity: line.quantity,
                sku: line.sku,
                supplier: line.supplier,
                shippingId: shipping?.id,
                shippingName: shipping?.name,
                shippingDescription: shipping?.description,
                shippingAmount: shippingPrice,
                shippingCurrency: shippingCurrency,
                availableShippings: availableShippings
            )
        }

        sponsorCart.items = mapped
        sponsorCart.subtotal = mapped.reduce(0.0) { total, item in
            total + (item.price * Double(item.quantity))
        }
        sponsorCart.shippingTotal = mapped.reduce(0.0) { total, item in
            total + (item.shippingAmount ?? 0.0)
        }
        sponsorCart.shippingCurrency = mapped.first(where: { $0.shippingCurrency != nil })?.shippingCurrency ?? cart.currency
    }

    /// Q4 L3 B6 (2026-05-04): auto-selects the first available shipping
    /// option for every item in this sponsor's cart that doesn't have
    /// `shipping_id` set yet. Called from
    /// `addProduct(_:variant:quantity:sponsorId:)` after the addItem
    /// sync so the cart is immediately checkout-ready (Commerce's
    /// `applePayConfirm` rejects carts whose line items lack
    /// `shipping_id` with the generic `[object Object]` error).
    ///
    /// Mirrors the user's manual selection in legacy
    /// `VCheckoutOverlay.shippingOptionsSelectionView`. The
    /// `SponsorCheckoutSection` (Q4 L3 B1) doesn't expose a picker yet,
    /// so we pick the first option (typically the cheapest / default
    /// standard shipping). A future iteration can add a picker UI to
    /// let the user choose explicitly.
    ///
    /// Best-effort: failures here are logged but don't block the flow —
    /// the user can still attempt checkout, and Commerce will return
    /// the same `[object Object]` error if shipping is still missing.
    internal func autoSelectFirstShipping(
        forSponsor sponsorId: Int,
        sdk: CartManagingSDK
    ) async {
        guard var sponsorCart = cartsBySponsor[sponsorId],
              let cid = sponsorCart.cartId,
              !cid.isEmpty else { return }

        for item in sponsorCart.items {
            // Skip items that already have shipping selected, or items
            // with no available shipping options (e.g. digital goods).
            if let existing = item.shippingId, !existing.isEmpty { continue }
            guard let firstOption = item.availableShippings.first,
                  !firstOption.id.isEmpty else { continue }

            do {
                logRequest(
                    "sdk.cart.updateItem (sponsor=\(sponsorId), shipping auto-select)",
                    payload: [
                        "cart_id": cid,
                        "cart_item_id": item.id,
                        "shipping_id": firstOption.id
                    ]
                )
                let dto = try await sdk.cart.updateItem(
                    cart_id: cid,
                    cart_item_id: item.id,
                    shipping_id: firstOption.id,
                    quantity: nil
                )
                syncSponsorCart(&sponsorCart, from: dto)
                cartsBySponsor[sponsorId] = sponsorCart
                VioLogger.info(
                    "Auto-selected shipping=\(firstOption.id) (\(firstOption.name)) for item \(item.id) sponsor=\(sponsorId)",
                    component: "CartModule"
                )
            } catch {
                VioLogger.warning(
                    "Auto-select shipping FAILED for item \(item.id) sponsor=\(sponsorId): \(error.localizedDescription)",
                    component: "CartModule"
                )
                // Continue with next item — best-effort.
            }
        }
    }

    /// Local fallback when the Reachu addItem/updateItem call throws.
    /// Mirrors the existing private `addProductLocally` for the flat
    /// path but writes into the SponsorCart instead of the global state.
    internal func addItemLocallyToSponsorCart(
        _ sponsorCart: inout SponsorCart,
        product: Product,
        variant: VioCore.Variant?,
        quantity: Int
    ) {
        let variantId = variant?.id
        let variantTitle = variant?.title
        let priceToUse = variant?.price ?? product.price
        let imageUrl = product.images.first?.url

        if let index = sponsorCart.items.firstIndex(where: {
            $0.productId == product.id && $0.variantId == variantId
        }) {
            sponsorCart.items[index].quantity += quantity
        } else {
            let item = CartItem(
                id: "local-\(UUID().uuidString)",
                productId: product.id,
                variantId: variantId,
                variantTitle: variantTitle,
                title: product.title,
                brand: product.brand,
                imageUrl: imageUrl,
                price: Double(priceToUse.amount_incl_taxes ?? priceToUse.amount),
                currency: priceToUse.currency_code,
                quantity: quantity,
                sku: variant?.sku ?? product.sku,
                supplier: product.supplier,
                shippingId: nil,
                shippingName: nil,
                shippingDescription: nil,
                shippingAmount: nil,
                shippingCurrency: priceToUse.currency_code,
                availableShippings: []
            )
            sponsorCart.items.append(item)
        }
        // Recompute subtotal — same formula as syncSponsorCart.
        sponsorCart.subtotal = sponsorCart.items.reduce(0.0) { total, item in
            total + (item.price * Double(item.quantity))
        }
    }
}
