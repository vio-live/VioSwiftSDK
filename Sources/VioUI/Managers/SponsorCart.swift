import Foundation

@MainActor
extension CartManager {

    /// One cart per sponsor — see `CartManager.cartsBySponsor`.
    ///
    /// **Why per-sponsor:** each sponsor uses its own Reachu Commerce channel
    /// (with its own `commerce_api_key` from the subscribe response). A cart
    /// created with one channel's key cannot be checked out with another's,
    /// so a multi-sponsor store needs N concurrent carts.
    ///
    /// **Apple Pay note:** the merchant identifier (`merchant.live.vio`) stays
    /// the same across sponsors — Vio acts as the Apple Pay aggregator and
    /// Reachu performs the per-sponsor settlement post-payment. So users see
    /// "Vio" in the Apple Pay sheet even when paying for an XXL or Elkjøp
    /// item; the channel split is invisible to them and happens server-side.
    ///
    /// **Aggregates:** `CartManager` exposes back-compat flat readers
    /// (`items`, `cartTotal`, `itemCount`) that aggregate across every
    /// `SponsorCart` so existing UI bound to `@EnvironmentObject CartManager`
    /// keeps working without per-sponsor awareness.
    public struct SponsorCart: Identifiable, Equatable {
        /// Sponsor row id this cart belongs to (`sponsors.id`). Stable as long
        /// as the campaign/sponsor pair is alive.
        public let sponsorId: Int

        /// Reachu Cart row id, set by `Cart.create` for this sponsor's channel.
        /// Nil until the first item is added.
        public var cartId: String?

        /// Set by `Checkout.create` for this sponsor's channel. Independent
        /// from `cartId` (Reachu requirement). Nil until checkout starts.
        public var checkoutId: String?

        /// Line items for this sponsor's cart only. Mirrors what Reachu has
        /// for the (cartId, channel) pair.
        public var items: [CartItem]

        /// Sum of (item.price.amount × quantity) for this sponsor's items.
        /// Updated by `CartManager` whenever `items` changes.
        public var subtotal: Double

        /// Currency code for this sponsor's cart (e.g. "NOK"). Reachu locks
        /// this at cart creation; mixing currencies across sponsors is fine
        /// at the `cartsBySponsor` level — each cart keeps its own.
        public var currency: String

        /// Country code for shipping (e.g. "NO"). Same scope as `currency`.
        public var country: String

        /// Shipping total for this sponsor's items only.
        public var shippingTotal: Double

        /// Shipping currency (usually matches `currency` but Reachu allows split).
        public var shippingCurrency: String

        /// Discount code applied to this sponsor's cart.
        public var lastDiscountCode: String?

        /// Discount row id matching `lastDiscountCode`.
        public var lastDiscountId: Int?

        /// Payment method picked by the user for this sponsor's checkout
        /// (Q4 L4, 2026-05-06). Set from the cart screen's per-sponsor
        /// method picker; consumed by the per-sponsor checkout flow which
        /// branches by method (Apple Pay → direct sheet, Klarna → full
        /// address form, Vipps/Stripe → email-only). Nil = not picked
        /// yet, the section's "Checkout" button stays disabled.
        ///
        /// Allowed string values mirror `VioSponsor.CommerceBlock.paymentMethods`
        /// — typically `"apple"`, `"klarna"`, `"vipps"`, `"stripe"`. Stored
        /// as String (not enum) so backend can introduce new methods
        /// without an SDK release; the cart UI filters the picker to
        /// the sponsor's supported methods anyway.
        public var selectedPaymentMethod: String?

        /// True when this sponsor's checkout has completed successfully
        /// (Q4 L4, 2026-05-06). The cart UI keeps the section visible but
        /// dimmed with a "Paid" badge so the user can see progress
        /// across sponsors. Cleared together with the rest of the cart
        /// state by `clearCart(forSponsor:)`.
        public var isPaid: Bool

        public var id: Int { sponsorId }

        public init(
            sponsorId: Int,
            cartId: String? = nil,
            checkoutId: String? = nil,
            items: [CartItem] = [],
            subtotal: Double = 0,
            currency: String = "USD",
            country: String = "US",
            shippingTotal: Double = 0,
            shippingCurrency: String = "USD",
            lastDiscountCode: String? = nil,
            lastDiscountId: Int? = nil,
            selectedPaymentMethod: String? = nil,
            isPaid: Bool = false
        ) {
            self.sponsorId = sponsorId
            self.cartId = cartId
            self.checkoutId = checkoutId
            self.items = items
            self.subtotal = subtotal
            self.currency = currency
            self.country = country
            self.shippingTotal = shippingTotal
            self.shippingCurrency = shippingCurrency
            self.lastDiscountCode = lastDiscountCode
            self.lastDiscountId = lastDiscountId
            self.selectedPaymentMethod = selectedPaymentMethod
            self.isPaid = isPaid
        }

        /// Convenience: count items in this sponsor's cart (sum of quantities).
        public var itemCount: Int {
            items.reduce(0) { $0 + $1.quantity }
        }
    }
}
