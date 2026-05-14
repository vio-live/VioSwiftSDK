import SwiftUI
import VioCore
import VioDesignSystem

// MARK: - Shared cart-item row
//
// Single source of truth for how one product line renders inside a
// cart. Used by BOTH carts:
//   - legacy single-cart step flow → `VCheckoutOverlay.individualProductsWithQuantityView`
//   - multi-sponsor cart           → `SponsorCheckoutSection.itemRow`
//
// **Why this exists** — before extraction the two carts had duplicated,
// drifting row implementations:
//   - legacy used config-driven `adaptiveColors` for colours but
//     hardcoded `.system(size:)` fonts
//   - multi-sponsor used static `VioColors.*` (not colour-scheme /
//     config aware) + `VioTypography`
// The user's directive (2026-05-14): "usa componentes y no rehagas las
// cosas. legacy toma muchas cosas del config file esto tambien deberia
// ser asi." So this component is the component, and it's **fully
// config-driven**:
//   - colours  → `VioColors.adaptive(for: colorScheme)` →
//     `VioConfiguration.shared.theme`
//   - fonts    → `VioTypography` tokens (theme-scaled, never `.system`)
//   - spacing  → `VioSpacing` / `VioBorderRadius`
//
// **Pure presentation** — no `CartManager` dependency. Quantity
// mutations are delegated to the call site via the `onIncrement` /
// `onDecrement` closures, because the legacy cart and the multi-sponsor
// cart call different CartManager APIs (`updateQuantity(for:to:)` vs
// `updateQuantity(for:to:fromSponsor:)`). The call site also owns the
// "decrement, or remove if this is the last unit" semantics.

@MainActor
public struct VCartItemRow: View {

    /// The cart item to render.
    public let item: CartManager.CartItem

    /// Parsed variant options as name/value pairs (e.g.
    /// `[("Size", "S"), ("Color", "Red")]`). When empty, the row falls
    /// back to showing `item.variantTitle` as a plain line (if it has
    /// one). The legacy cart passes its `optionDetails(for:)` output;
    /// the multi-sponsor cart passes nothing and gets the variantTitle
    /// fallback.
    public let optionDetails: [(name: String, value: String)]

    /// Tapped "+" — the call site wires this to the right CartManager
    /// API (flat `updateQuantity(for:to:)` or sponsor-scoped
    /// `updateQuantity(for:to:fromSponsor:)`).
    public let onIncrement: () -> Void

    /// Tapped "−" / trash — the call site owns the "decrement, or
    /// remove if `item.quantity == 1`" decision. The row only decides
    /// which *icon* to show (trash when this is the last unit).
    public let onDecrement: () -> Void

    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    public init(
        item: CartManager.CartItem,
        optionDetails: [(name: String, value: String)] = [],
        onIncrement: @escaping () -> Void,
        onDecrement: @escaping () -> Void
    ) {
        self.item = item
        self.optionDetails = optionDetails
        self.onIncrement = onIncrement
        self.onDecrement = onDecrement
    }

    /// Config-driven colour set — resolves through
    /// `VioConfiguration.shared.theme` and the active colour scheme.
    private var colors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }

    public var body: some View {
        VStack(spacing: VioSpacing.md) {
            // Row 1 — image · (brand / title / qty controls) · unit price
            HStack(spacing: VioSpacing.md) {
                productImage

                VStack(alignment: .leading, spacing: VioSpacing.xs) {
                    if let brand = item.brand, !brand.isEmpty {
                        Text(brand)
                            .font(VioTypography.footnote)
                            .foregroundColor(colors.textSecondary)
                    }

                    Text(item.title)
                        .font(VioTypography.subheadline.weight(.semibold))
                        .foregroundColor(colors.textPrimary)
                        .lineLimit(2)

                    quantityControls
                }

                Spacer()

                Text(formattedPrice(item.price))
                    .font(VioTypography.subheadline.weight(.semibold))
                    .foregroundColor(colors.priceColor)
            }

            // Row 2 — variant detail (name: value rows, or plain title)
            detailRows

            // Row 3 — line total ("Total for this item")
            HStack {
                Text("Total for this item:")
                    .font(VioTypography.footnote)
                    .foregroundColor(colors.textSecondary)

                Spacer()

                Text(formattedPrice(item.price * Double(item.quantity)))
                    .font(VioTypography.footnote.weight(.semibold))
                    .foregroundColor(colors.priceColor)
            }
        }
    }

    // MARK: - Sub-views

    /// 60×60 product thumbnail. `LoadedImage` (the SDK's cached image
    /// loader) with a rotating placeholder and a neutral error fill —
    /// same loader the legacy cart used.
    private var productImage: some View {
        LoadedImage(
            url: URL(string: item.imageUrl ?? ""),
            placeholder: AnyView(VCustomLoader(style: .rotate, size: 30)),
            errorView: AnyView(Rectangle().fill(colors.surfaceSecondary))
        )
        .aspectRatio(contentMode: .fill)
        .frame(width: 60, height: 60)
        .clipped()
        .cornerRadius(VioBorderRadius.medium)
    }

    /// `[ trash/− ] [ qty ] [ + ]` — squarish buttons on a
    /// `surfaceSecondary` fill, sitting directly below the title (the
    /// legacy layout). The decrement button shows the trash glyph in
    /// the theme's `error` colour when this is the last unit, so the
    /// user sees that tapping it removes the line.
    private var quantityControls: some View {
        HStack(spacing: VioSpacing.sm) {
            Button(action: onDecrement) {
                Image(systemName: item.quantity == 1 ? "trash" : "minus")
                    .font(VioTypography.footnote)
                    .foregroundColor(
                        item.quantity == 1 ? colors.error : colors.textPrimary
                    )
                    .frame(width: 28, height: 28)
                    .background(colors.surfaceSecondary)
                    .cornerRadius(VioBorderRadius.small)
            }
            .buttonStyle(.plain)

            Text("\(item.quantity)")
                .font(VioTypography.subheadline.weight(.semibold))
                .foregroundColor(colors.textPrimary)
                .frame(width: 30)
                .animation(.spring(), value: item.quantity)

            Button(action: onIncrement) {
                Image(systemName: "plus")
                    .font(VioTypography.footnote)
                    .foregroundColor(colors.textPrimary)
                    .frame(width: 28, height: 28)
                    .background(colors.surfaceSecondary)
                    .cornerRadius(VioBorderRadius.small)
            }
            .buttonStyle(.plain)
        }
    }

    /// Variant detail block. Prefers the parsed `optionDetails`
    /// (`Size: S` / `Color: Red` rows); when the caller passes none,
    /// falls back to the raw `item.variantTitle` on a single line so
    /// the multi-sponsor cart (which doesn't compute option details)
    /// still shows the variant.
    @ViewBuilder
    private var detailRows: some View {
        if !optionDetails.isEmpty {
            VStack(spacing: VioSpacing.xs) {
                ForEach(Array(optionDetails.enumerated()), id: \.offset) { _, detail in
                    HStack {
                        Text("\(detail.name):")
                            .font(VioTypography.footnote)
                            .foregroundColor(colors.textSecondary)
                        Spacer()
                        Text(detail.value)
                            .font(VioTypography.footnote)
                            .foregroundColor(colors.textSecondary)
                    }
                }
            }
        } else if let variant = item.variantTitle, !variant.isEmpty {
            HStack {
                Text(variant)
                    .font(VioTypography.footnote)
                    .foregroundColor(colors.textSecondary)
                Spacer()
            }
        }
    }

    // MARK: - Helpers

    /// Matches the legacy formatter — `"<CURRENCY> <amount>"` with two
    /// fraction digits (e.g. `"NOK 199.00"`).
    private func formattedPrice(_ value: Double) -> String {
        "\(item.currency) \(String(format: "%.2f", value))"
    }
}
