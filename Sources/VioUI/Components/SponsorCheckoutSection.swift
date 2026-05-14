import SwiftUI
import VioCore
import VioDesignSystem

// MARK: - Q4 Layer 4: per-sponsor checkout section (method picker + Checkout)
//
// Renders one SponsorCart inside the multi-sponsor checkout view. Each
// section is self-contained: header (logo + name + subtotal), items
// (compact), totals row (subtotal + shipping + total), method picker,
// and a "Checkout" button that hands off to the per-sponsor checkout
// flow with the chosen method.
//
// **Q4 L4 (2026-05-06): method picker before checkout.** The user picks
// the payment method per sponsor (filtered to that sponsor's
// `commerce.paymentMethods` set) directly in the cart, *before* tapping
// Checkout. This lets the per-sponsor flow branch by method without
// asking again later:
//   - Apple Pay → direct native sheet, no extra step
//   - Klarna   → full BuyerInfo form (klarnaNativeInit needs address)
//   - Vipps    → email-only form (Vipps app collects the rest)
//   - Stripe   → email-only form (PaymentSheet collects card+address)
//
// **Paid state**: when the per-sponsor flow completes successfully, the
// parent calls `cartManager.markSponsorCartPaid(sponsorId)` and the
// section stays visible with `isPaid = true` (dimmed + green "Paid"
// badge). Final cleanup happens in `clearCart(forSponsor:)` on close.
//
// **Pre Q4 L4 history**: section used to expose only Apple Pay (Q4 L3
// PR #11 — multi-sponsor was Apple-Pay-only that sprint). Now Klarna
// / Vipps / Stripe are first-class via the per-method handlers turned
// sponsor-aware in Q4 L4 phases 2-4.

@MainActor
public struct SponsorCheckoutSection: View {

    /// The cart this section renders. The parent view (VCheckoutOverlay)
    /// passes one SponsorCart per item from `cartManager.cartsBySponsor`.
    public let sponsorCart: CartManager.SponsorCart

    /// Callback fired when the user taps a payment-method action button
    /// for this sponsor's cart. The parent (`VCheckoutOverlay`) is
    /// responsible for opening the per-sponsor checkout flow and handing
    /// back to `markSponsorCartPaid` / `clearCart(forSponsor:)` on
    /// completion.
    ///
    /// **The `String` argument is the tapped method** (already
    /// normalized — lowercase, no `_`/spaces, `stripelink`→`stripe`).
    /// Sprint feat/skip-ordersummary-after-address (2026-05-14): the
    /// callback used to be `() -> Void` and the parent re-read
    /// `sponsorCart.selectedPaymentMethod` to know which method was
    /// tapped. But `sponsorCart` is a SwiftUI value snapshot captured
    /// at render time — by the time the button's action runs, the
    /// `setSelectedPaymentMethod` write has updated
    /// `cartManager.cartsBySponsor[id]` but the captured snapshot is
    /// still stale. That caused two real bugs in the multi-sponsor
    /// cart: (1) needing to tap a method twice (first tap read the
    /// stale nil/previous value), and (2) tapping "Card" firing Apple
    /// Pay (stale value was a previously-tapped "apple_pay"). Passing
    /// the method explicitly removes the dependency on the snapshot.
    ///
    /// Q4 L4 (2026-05-06): originally renamed from `onPaymentComplete`
    /// since the section no longer drives the payment itself — it only
    /// signals intent + selected method.
    public let onCheckoutTapped: (String) -> Void

    @EnvironmentObject private var cartManager: CartManager

    public init(
        sponsorCart: CartManager.SponsorCart,
        onCheckoutTapped: @escaping (String) -> Void = { _ in }
    ) {
        self.sponsorCart = sponsorCart
        self.onCheckoutTapped = onCheckoutTapped
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VioSpacing.md) {
            sponsorHeader
            Divider().background(Color.white.opacity(0.1))
            itemsList
            Divider().background(Color.white.opacity(0.1))
            totalsRow
            if sponsorCart.isPaid {
                paidBanner
            } else {
                methodActionButtons
            }
        }
        .padding(VioSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: VioBorderRadius.large)
                .fill(VioColors.surface.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VioBorderRadius.large)
                .stroke(sponsorCart.isPaid ? VioColors.success.opacity(0.5) : VioColors.border, lineWidth: 1)
        )
        .opacity(sponsorCart.isPaid ? 0.65 : 1)
    }

    // MARK: - Header (logo + name + subtotal)

    private var sponsorHeader: some View {
        HStack(spacing: VioSpacing.md) {
            sponsorLogo
            VStack(alignment: .leading, spacing: 4) {
                Text(sponsorName)
                    .font(VioTypography.headline)
                    .foregroundColor(VioColors.textPrimary)
                Text("\(itemCountText)")
                    .font(VioTypography.caption1)
                    .foregroundColor(VioColors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(VLocalizedString(VioTranslationKey.subtotal.rawValue))
                    .font(VioTypography.caption1)
                    .foregroundColor(VioColors.textSecondary)
                Text(formatMoney(sponsorCart.subtotal, code: sponsorCart.currency))
                    .font(VioTypography.headline)
                    .foregroundColor(VioColors.textPrimary)
            }
        }
    }

    @ViewBuilder
    private var sponsorLogo: some View {
        if let logoStr = resolvedSponsorLogoUrl {
            // `VRemoteImage` is the SDK's format-agnostic remote image
            // renderer (same one VProductCarousel / VProductSpotlight
            // headers use). It routes `.svg` URLs through a WKWebView —
            // WebKit renders any valid SVG — and raster URLs (PNG/JPEG/
            // WebP) through `AsyncImage`. This is why e.g. XXL #7,
            // whose `logo_url` is an `.svg`, now shows its real logo
            // instead of the "XXX" text placeholder: the raw
            // `AsyncImage` we used before could not decode SVG.
            //
            // `.leading` alignment so the logo sits at the left edge of
            // the 56-wide frame (matches the header layout — logo, then
            // name + item count to its right).
            VRemoteImage(urlString: logoStr, height: 32, alignment: .leading)
                .frame(width: 56, height: 32)
        } else {
            // Only reached when the sponsor has neither a `logoUrl` nor
            // an `avatarUrl` — `resolvedSponsorLogoUrl` returns nil.
            placeholderLogo
                .frame(width: 56, height: 32)
        }
    }

    private var placeholderLogo: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(VioColors.surface.opacity(0.3))
            .overlay(
                Text(sponsorName.prefix(3).uppercased())
                    .font(VioTypography.caption1.weight(.bold))
                    .foregroundColor(VioColors.textSecondary)
            )
    }

    // MARK: - Items list (compact)

    private var itemsList: some View {
        VStack(spacing: VioSpacing.sm) {
            ForEach(sponsorCart.items) { item in
                itemRow(item)
            }
        }
    }

    /// One product line. Sprint feat/skip-ordersummary-after-address
    /// (2026-05-14): replaced the inline `HStack` (which used static
    /// `VioColors.*` + a different layout from the legacy cart) with
    /// the shared `VCartItemRow` component. Now the multi-sponsor cart
    /// and the legacy single-cart render product rows **identically**
    /// and both stay config-driven (theme colours + VioTypography).
    ///
    /// The component is pure presentation — quantity mutations route
    /// through the sponsor-scoped CartManager APIs
    /// (`updateQuantity(for:to:fromSponsor:)` / `removeItem(_:fromSponsor:)`)
    /// via the closures below, mirroring the legacy cart's "decrement,
    /// or remove the last unit" semantics.
    private func itemRow(_ item: CartManager.CartItem) -> some View {
        VCartItemRow(
            item: item,
            onIncrement: {
                Task {
                    await cartManager.updateQuantity(
                        for: item,
                        to: item.quantity + 1,
                        fromSponsor: sponsorCart.sponsorId
                    )
                }
            },
            onDecrement: {
                Task {
                    if item.quantity > 1 {
                        await cartManager.updateQuantity(
                            for: item,
                            to: item.quantity - 1,
                            fromSponsor: sponsorCart.sponsorId
                        )
                    } else {
                        await cartManager.removeItem(
                            item,
                            fromSponsor: sponsorCart.sponsorId
                        )
                    }
                }
            }
        )
    }

    // MARK: - Totals row (subtotal + shipping + total)

    private var totalsRow: some View {
        VStack(spacing: VioSpacing.xs) {
            HStack {
                Text(VLocalizedString(VioTranslationKey.subtotal.rawValue))
                    .font(VioTypography.body)
                    .foregroundColor(VioColors.textSecondary)
                Spacer()
                Text(formatMoney(sponsorCart.subtotal, code: sponsorCart.currency))
                    .font(VioTypography.body)
                    .foregroundColor(VioColors.textPrimary)
            }
            if sponsorCart.shippingTotal > 0 {
                HStack {
                    Text(VLocalizedString(VioTranslationKey.shipping.rawValue))
                        .font(VioTypography.body)
                        .foregroundColor(VioColors.textSecondary)
                    Spacer()
                    Text(formatMoney(sponsorCart.shippingTotal, code: sponsorCart.shippingCurrency))
                        .font(VioTypography.body)
                        .foregroundColor(VioColors.textPrimary)
                }
            }
            HStack {
                Text(VLocalizedString(VioTranslationKey.total.rawValue))
                    .font(VioTypography.headline)
                    .foregroundColor(VioColors.textPrimary)
                Spacer()
                Text(formatMoney(sponsorCart.subtotal + sponsorCart.shippingTotal,
                                 code: sponsorCart.currency))
                    .font(VioTypography.headline.weight(.bold))
                    .foregroundColor(VioColors.textPrimary)
            }
        }
    }

    // MARK: - Method picker (Q4 L4)

    /// Available payment methods for this sponsor — comes from
    /// `commerce.paymentMethods` in the bootstrap response. Empty array
    /// means visual-only sponsor (no commerce block) which shouldn't
    /// reach this view in the first place; we still degrade safely by
    /// disabling the picker.
    private var availableMethods: [String] {
        let raw = VioConfiguration.shared.sponsor(withId: sponsorCart.sponsorId)?.commerce?.paymentMethods ?? []
        // Stable order across renders + de-dup. Backend may send "apple_pay"
        // or "applePay"; we normalise to lowercase compact keys.
        let normalized = raw.map { rawMethod -> String in
            let key = rawMethod.lowercased()
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")
            // Sprint feat/skip-ordersummary-after-address (2026-05-14):
            // collapse "stripelink" → "stripe". The backend's
            // `sponsors.payment_methods` ships "stripe_link" for every
            // commerce sponsor, but the SDK deliberately does NOT expose
            // Stripe Link as a distinct method — the product decision is
            // the plain native PaymentSheet card experience, nothing
            // cross-merchant. `PaymentMethod` enum only has `.stripe`,
            // and `handleSponsorCheckoutTap` matches `case "stripe"`.
            // Mapping here means one "Card" button that routes cleanly
            // to native Stripe, instead of a "stripelink" string that
            // falls through `handleSponsorCheckoutTap`'s `default:
            // break` (latent bug — tapping "Card" after having tapped
            // Klarna would leave `selectedPaymentMethod` at `.klarna`
            // and fire the wrong flow).
            return key == "stripelink" ? "stripe" : key
        }
        // de-dup also collapses the case where the backend ever sends
        // BOTH "stripe" and "stripe_link" — both normalise to "stripe".
        var seen = Set<String>()
        return normalized.filter { seen.insert($0).inserted }
    }

    /// UX (2026-05-13): one-tap payment action list. Replaces the
    /// previous two-step "pick method chip → tap Kasse →" pattern with
    /// a vertical list of full-width primary buttons, one per backend-
    /// active method. Tapping a button sets the SponsorCart's
    /// `selectedPaymentMethod` (so downstream flow controllers can
    /// branch by method as before) AND immediately dispatches
    /// `onCheckoutTapped`, removing the need for a separate "Kasse"
    /// CTA.
    ///
    /// Methods come from `sponsor.commerce.paymentMethods` in the
    /// `/v2/mobile/config` bootstrap response — strictly backend-
    /// driven. No client-side filtering or hardcoding. If the array
    /// is empty (visual-only sponsor or misconfigured backend), the
    /// section renders the noPaymentMethods empty state instead of
    /// disabled buttons.
    @ViewBuilder
    private var methodActionButtons: some View {
        if availableMethods.isEmpty {
            Text(VLocalizedString(VioTranslationKey.noPaymentMethods.rawValue))
                .font(VioTypography.body)
                .foregroundColor(VioColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, VioSpacing.md)
        } else {
            VStack(alignment: .leading, spacing: VioSpacing.sm) {
                Text(VLocalizedString(VioTranslationKey.paymentMethod.rawValue))
                    .font(VioTypography.caption1.weight(.semibold))
                    .foregroundColor(VioColors.textSecondary)

                ForEach(availableMethods, id: \.self) { method in
                    methodActionButton(method)
                }
            }
        }
    }

    /// Single-tap action button per payment method. Visually distinct
    /// from the legacy chip — full-width, primary CTA height, leading
    /// icon + label + trailing chevron.
    ///
    /// All font sizes use `VioTypography` tokens so the button scales
    /// with the host's design-system configuration (no hardcoded points).
    @ViewBuilder
    private func methodActionButton(_ method: String) -> some View {
        Button {
            // Persist the choice on the sponsor cart (kept for any
            // re-render / visual-state consumers) AND pass the method
            // explicitly to the parent — the parent must NOT re-read
            // `sponsorCart.selectedPaymentMethod` from its captured
            // snapshot (stale; see `onCheckoutTapped` doc-comment).
            cartManager.setSelectedPaymentMethod(method, forSponsor: sponsorCart.sponsorId)
            onCheckoutTapped(method)
        } label: {
            HStack(spacing: VioSpacing.sm) {
                methodIcon(method)
                Text(methodLabel(method))
                    .font(VioTypography.bodyBold)
                    .foregroundColor(VioColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(VioTypography.footnote.weight(.semibold))
                    .foregroundColor(VioColors.textSecondary)
            }
            .padding(.horizontal, VioSpacing.md)
            .frame(maxWidth: .infinity)
            .padding(.vertical, VioSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                    .fill(VioColors.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                    .stroke(VioColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(VLocalizedString(VioTranslationKey.checkout.rawValue)) \(sponsorName) \(methodLabel(method))"
        )
    }

    @ViewBuilder
    private func methodIcon(_ method: String) -> some View {
        // Brand mark per method, sized via `VioTypography` so it
        // tracks the label scale and any host-side Dynamic Type
        // settings. Brand colors are still literal because they
        // are part of the payment-network identity, not the host
        // theme — Apple Pay logo is black/white, Klarna is pink,
        // Vipps is orange, Stripe is purple-ish.
        switch method {
        case "apple", "applepay":
            Image(systemName: "applelogo")
                .font(VioTypography.bodyBold)
                .foregroundColor(VioColors.textPrimary)
        case "klarna":
            Text("K.")
                .font(VioTypography.bodyBold)
                .foregroundColor(Color(red: 1.0, green: 0.66, blue: 0.8))
        case "vipps":
            Text("V")
                .font(VioTypography.bodyBold)
                .foregroundColor(Color(red: 1.0, green: 0.36, blue: 0.14))
        case "stripe", "stripelink":
            Image(systemName: "creditcard.fill")
                .font(VioTypography.bodyBold)
                .foregroundColor(Color(red: 0.39, green: 0.36, blue: 1.0))
        case "googlepay":
            // Generic placeholder — Google branding requires asset
            // licensing not currently bundled. Card glyph for now.
            Image(systemName: "creditcard")
                .font(VioTypography.bodyBold)
                .foregroundColor(VioColors.textPrimary)
        default:
            Image(systemName: "creditcard")
                .font(VioTypography.body)
                .foregroundColor(VioColors.textSecondary)
        }
    }

    private func methodLabel(_ method: String) -> String {
        switch method {
        case "apple", "applepay": return "Apple Pay"
        case "klarna": return "Klarna"
        case "vipps": return "Vipps"
        case "stripe": return "Card"
        case "stripelink": return "Card"
        case "googlepay": return "Google Pay"
        default: return method.capitalized
        }
    }

    // MARK: - Paid banner (Q4 L4)

    /// Dimmed "Paid" banner shown in place of method picker + checkout
    /// button after this sponsor's checkout completes. Keeps the section
    /// visible so the user sees progress across sponsors.
    private var paidBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(VioColors.success)
            Text(VLocalizedString(VioTranslationKey.cartSponsorPaid.rawValue).capitalized)
                .font(VioTypography.body.weight(.semibold))
                .foregroundColor(VioColors.success)
            Spacer()
        }
        .padding(.vertical, VioSpacing.sm)
        .padding(.horizontal, VioSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                .fill(VioColors.success.opacity(0.12))
        )
    }

    // MARK: - Helpers

    private var sponsorName: String {
        VioConfiguration.shared.sponsor(withId: sponsorCart.sponsorId)?.name
            ?? "Sponsor #\(sponsorCart.sponsorId)"
    }

    /// The image URL the section header renders in its 56×32 logo
    /// frame. Prefers the wide `logoUrl` (fills that frame better than
    /// the square `avatarUrl`).
    ///
    /// SVG `logoUrl` is fine here — `sponsorLogo` renders through
    /// `VRemoteImage`, which routes `.svg` URLs through a WKWebView
    /// (WebKit decodes any valid SVG). An earlier fix (commit
    /// `5a4be2a`) skipped SVG and fell back to the avatar because the
    /// header used a raw `AsyncImage` that can't decode SVG — that
    /// workaround is now superseded by the `VRemoteImage` switch, so
    /// we go back to simply preferring the wide logo.
    ///
    /// `nil` only when the sponsor has neither a `logoUrl` nor an
    /// `avatarUrl` — then `sponsorLogo` renders `placeholderLogo`.
    private var resolvedSponsorLogoUrl: String? {
        let sponsor = VioConfiguration.shared.sponsor(withId: sponsorCart.sponsorId)
        // 1. Wide logo (SVG or raster — VRemoteImage handles both).
        if let logo = sponsor?.logoUrl, !logo.isEmpty {
            return logo
        }
        // 2. Fall back to the square avatar.
        if let avatar = sponsor?.avatarUrl, !avatar.isEmpty {
            return avatar
        }
        // 3. Nothing usable → placeholder.
        return nil
    }

    private var itemCountText: String {
        let count = sponsorCart.itemCount
        return count == 1 ? "1 vare" : "\(count) varer"
    }

    private func formatMoney(_ value: Double, code: String) -> String {
        // Match VApplePayConfirmationSheet's formatter for visual consistency.
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(code) \(value)"
    }
}
