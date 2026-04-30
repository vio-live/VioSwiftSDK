import SwiftUI
import VioCore
import VioDesignSystem

// MARK: - Q4 Layer 3: per-sponsor checkout section
//
// Renders one SponsorCart inside the multi-sponsor checkout view. Each
// section is self-contained: header (logo + name + subtotal), items
// (compact), totals row (subtotal + shipping + total), and an Apple Pay
// button scoped to that sponsor (`sponsorId` already plumbed via Q4 L1).
//
// On successful Apple Pay completion, the section calls
// `cartManager.clearCart(forSponsor:)` for its sponsor — that drops the
// SponsorCart from `cartsBySponsor`, and SwiftUI re-renders the parent
// `VCheckoutOverlay` without this section. Other sponsors' sections
// stay intact.
//
// Klarna / Vipps / Stripe are deliberately **not exposed in this
// section**: per the UX decisions on Q4 L3 (PR #11 plan), multi-sponsor
// stores are Apple-Pay-only this sprint. Klarna/Vipps/Stripe stay
// available in the legacy single-cart path. A user with multi-sponsor
// items who wants Klarna would need to clear all carts and re-add
// items one sponsor at a time — friction we accept to avoid the 3-4 day
// refactor of the Klarna / Vipps / Stripe handlers.

@MainActor
public struct SponsorCheckoutSection: View {

    /// The cart this section renders. The parent view (VCheckoutOverlay)
    /// passes one SponsorCart per item from `cartManager.cartsBySponsor`.
    public let sponsorCart: CartManager.SponsorCart

    /// Callback fired when the user completes an Apple Pay purchase
    /// for this sponsor's cart. The section already calls
    /// `cartManager.clearCart(forSponsor:)` internally — this callback
    /// is for the parent to dismiss banners, advance steps, or update
    /// other UI state on top of the cart removal.
    public let onPaymentComplete: () -> Void

    @EnvironmentObject private var cartManager: CartManager

    public init(
        sponsorCart: CartManager.SponsorCart,
        onPaymentComplete: @escaping () -> Void = {}
    ) {
        self.sponsorCart = sponsorCart
        self.onPaymentComplete = onPaymentComplete
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VioSpacing.md) {
            sponsorHeader
            Divider().background(Color.white.opacity(0.1))
            itemsList
            Divider().background(Color.white.opacity(0.1))
            totalsRow
            #if os(iOS)
            applePayActionRow
            #endif
        }
        .padding(VioSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: VioBorderRadius.large)
                .fill(VioColors.surface.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VioBorderRadius.large)
                .stroke(VioColors.border, lineWidth: 1)
        )
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

    // MARK: - Apple Pay action row

    #if os(iOS)
    @ViewBuilder
    private var applePayActionRow: some View {
        // VApplePayButton (Q4 L1) accepts sponsorId — propagates through to
        // the confirmation sheet so the post-purchase logo matches this
        // sponsor (not the global activeSponsorId).
        //
        // The amount we hand the button is `subtotal + shipping` —
        // matches what the sheet shows and what Apple Pay will charge.
        let totalAmount = sponsorCart.subtotal + sponsorCart.shippingTotal
        VApplePayButton(
            productName: payButtonLabel,
            productImageUrl: sponsorCart.items.first?.imageUrl,
            amount: totalAmount,
            sponsorId: sponsorCart.sponsorId,
            onPaymentComplete: {
                Task {
                    await cartManager.clearCart(forSponsor: sponsorCart.sponsorId)
                    onPaymentComplete()
                }
            }
        )
    }
    #endif

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

    private var payButtonLabel: String {
        let count = sponsorCart.itemCount
        let label = count == 1
            ? sponsorCart.items.first?.title ?? sponsorName
            : "\(count) varer fra \(sponsorName)"
        return label
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
