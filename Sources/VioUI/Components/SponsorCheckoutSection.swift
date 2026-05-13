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

    /// Callback fired when the user taps the "Checkout" button for this
    /// sponsor's cart. The parent (`VCheckoutOverlay`) is responsible
    /// for opening the per-sponsor checkout flow and handing back to
    /// `markSponsorCartPaid` / `clearCart(forSponsor:)` on completion.
    /// Q4 L4 (2026-05-06): renamed from `onPaymentComplete` since the
    /// section no longer drives the payment itself — it only signals
    /// intent + selected method.
    public let onCheckoutTapped: () -> Void

    @EnvironmentObject private var cartManager: CartManager

    public init(
        sponsorCart: CartManager.SponsorCart,
        onCheckoutTapped: @escaping () -> Void = {}
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
        if let logoStr = resolvedSponsorLogoUrl, let url = URL(string: logoStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fit)
                default:
                    placeholderLogo
                }
            }
            .frame(width: 56, height: 32)
        } else {
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

    private func itemRow(_ item: CartManager.CartItem) -> some View {
        HStack(spacing: VioSpacing.md) {
            itemImage(item)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(VioTypography.body)
                    .foregroundColor(VioColors.textPrimary)
                    .lineLimit(2)
                if let variant = item.variantTitle, !variant.isEmpty {
                    Text(variant)
                        .font(VioTypography.caption1)
                        .foregroundColor(VioColors.textSecondary)
                }
                Text("\(item.quantity) stk")
                    .font(VioTypography.caption1)
                    .foregroundColor(VioColors.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatMoney(item.price * Double(item.quantity), code: item.currency))
                    .font(VioTypography.body.weight(.semibold))
                    .foregroundColor(VioColors.textPrimary)
                quantityButtons(item)
            }
        }
    }

    @ViewBuilder
    private func itemImage(_ item: CartManager.CartItem) -> some View {
        if let urlStr = item.imageUrl, let url = URL(string: urlStr) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color.white.opacity(0.05)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "shippingbox")
                        .foregroundColor(VioColors.textSecondary)
                )
        }
    }

    @ViewBuilder
    private func quantityButtons(_ item: CartManager.CartItem) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                Task {
                    await cartManager.updateQuantity(
                        for: item,
                        to: item.quantity - 1,
                        fromSponsor: sponsorCart.sponsorId
                    )
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(VioColors.textSecondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                Task {
                    await cartManager.updateQuantity(
                        for: item,
                        to: item.quantity + 1,
                        fromSponsor: sponsorCart.sponsorId
                    )
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(VioColors.primary)
                    .font(.system(size: 18))
            }
            .buttonStyle(PlainButtonStyle())
        }
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
        let normalized = raw.map { $0.lowercased().replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "") }
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
            cartManager.setSelectedPaymentMethod(method, forSponsor: sponsorCart.sponsorId)
            onCheckoutTapped()
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

    private var resolvedSponsorLogoUrl: String? {
        let logo = VioConfiguration.shared.sponsor(withId: sponsorCart.sponsorId)?.logoUrl
        return (logo?.isEmpty == false) ? logo : nil
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
