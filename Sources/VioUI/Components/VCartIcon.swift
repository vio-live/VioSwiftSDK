import SwiftUI
import VioCore
import VioDesignSystem

/// Reusable cart-icon component with a count badge that aggregates across
/// every sponsor cart in `CartManager.cartsBySponsor`.
///
/// **Why this lives in the SDK** (Q4 L3 Fase C, 2026-05-04): host apps
/// like the TV2 demo were rendering their own cart icon + count by
/// reading `cartManager.items.count` directly. That count only reflects
/// the legacy single-cart `items` array — it misses items in
/// `cartsBySponsor[*]` once multi-sponsor mode is active. By exposing
/// `VCartIcon` from the SDK we centralise the read against
/// `cartManager.itemCountAcrossSponsors`, which sums across every
/// SponsorCart and falls back to the legacy `items.count` when no
/// sponsor cart exists. Hosts get correct multi-sponsor counts for free.
///
/// **Usage:**
/// ```swift
/// // In a NavigationView toolbar or a custom header:
/// VCartIcon()
///     .onTapGesture {
///         cartManager.isCheckoutPresented = true
///     }
/// ```
///
/// The icon is `cart` (filled when count > 0, outlined when 0). Badge
/// shows `count` as a small red circle in the top-trailing corner when
/// `count > 0`. Tap behaviour is the host's responsibility — the
/// component does not auto-open the checkout (so hosts can wrap it in
/// their own NavigationLink, sheet trigger, etc.).
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
public struct VCartIcon: View {

    @EnvironmentObject private var cartManager: CartManager

    /// Optional override for the icon size. Defaults to 22pt — matches
    /// the typical NavigationView toolbar item size.
    private let iconSize: CGFloat

    /// Optional override for the icon foreground color. Defaults to
    /// `VioColors.textPrimary`.
    private let iconColor: Color?

    /// Optional override for the badge background color. Defaults to
    /// `Color.red` — the iOS notification-badge convention.
    private let badgeColor: Color

    public init(
        iconSize: CGFloat = 22,
        iconColor: Color? = nil,
        badgeColor: Color = .red
    ) {
        self.iconSize = iconSize
        self.iconColor = iconColor
        self.badgeColor = badgeColor
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: count > 0 ? "cart.fill" : "cart")
                .font(.system(size: iconSize, weight: .medium))
                .foregroundColor(iconColor ?? VioColors.textPrimary)

            if count > 0 {
                Text(badgeLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 16, minHeight: 16)
                    .padding(.horizontal, count > 9 ? 4 : 0)
                    .background(
                        Capsule()
                            .fill(badgeColor)
                    )
                    .offset(x: 6, y: -6)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    /// Combined item count across all sponsor carts (Q4 L3) plus the
    /// legacy single-cart items array. Falls back to `cartManager.items
    /// .count` when no sponsor cart is in play (legacy single-cart hosts).
    private var count: Int {
        let sponsorCount = cartManager.itemCountAcrossSponsors
        if sponsorCount > 0 {
            return sponsorCount
        }
        return cartManager.items.reduce(0) { $0 + $1.quantity }
    }

    /// Visual label for the badge. 99+ caps the width when many items.
    private var badgeLabel: String {
        count > 99 ? "99+" : "\(count)"
    }

    private var accessibilityLabel: String {
        let cartLabel = VLocalizedString(VioTranslationKey.cart.rawValue)
        if count == 0 {
            return cartLabel
        }
        let unit = count == 1
            ? VLocalizedString(VioTranslationKey.item.rawValue)
            : VLocalizedString(VioTranslationKey.items.rawValue)
        return "\(cartLabel), \(count) \(unit)"
    }
}
