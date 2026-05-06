import SwiftUI
import VioCore
import VioDesignSystem

// MARK: - Q4 L4 Phase 7 (2026-05-06): All-sponsors-paid recap sheet
//
// Shown by `VCheckoutOverlay` when every sponsor cart in the
// multi-sponsor session has `isPaid == true`. Aggregates a recap of
// each sponsor's order + grand total, gives the user a single Close
// CTA that drains `cartsBySponsor` (clearing the local + Commerce
// carts) and dismisses the entire checkout overlay.
//
// Sourced from the Claude Design `AllDoneScreen` artboard.

@available(iOS 15.0, *)
@MainActor
public struct VAllDoneSheet: View {

    /// Snapshot of paid sponsor carts the parent passes in. Captured at
    /// mount time so the recap remains stable while we drain the carts
    /// in the background after Close.
    public let paidSponsorCarts: [CartManager.SponsorCart]

    /// Called when the user taps "Close". Parent is responsible for
    /// `clearAllCarts()` + dismissing the overlay.
    public let onClose: () -> Void

    @EnvironmentObject private var cartManager: CartManager

    public init(
        paidSponsorCarts: [CartManager.SponsorCart],
        onClose: @escaping () -> Void
    ) {
        self.paidSponsorCarts = paidSponsorCarts
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: VioSpacing.lg) {
                    hero
                    perSponsorRecap
                    grandTotalCard
                }
                .padding(VioSpacing.lg)
            }
            closeButton
        }
        .background(VioColors.background)
    }

    private var hero: some View {
        VStack(spacing: VioSpacing.sm) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                VioColors.primary.opacity(0.30),
                                VioColors.primary.opacity(0.0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 55
                        )
                    )
                    .frame(width: 110, height: 110)
                Circle()
                    .fill(VioColors.primary)
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, VioSpacing.md)
            Text("All orders placed")
                .font(VioTypography.title1.weight(.bold))
                .foregroundColor(VioColors.textPrimary)
            Text(subtitleText)
                .font(VioTypography.body)
                .foregroundColor(VioColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, VioSpacing.md)
        }
    }

    private var subtitleText: String {
        let count = paidSponsorCarts.count
        if count == 1 {
            return "You completed 1 checkout. The sponsor will fulfill your order."
        }
        return "You completed \(count) checkouts. Each sponsor will fulfill their order separately."
    }

    private var perSponsorRecap: some View {
        VStack(spacing: VioSpacing.sm) {
            ForEach(paidSponsorCarts, id: \.sponsorId) { cart in
                sponsorRecapRow(cart)
            }
        }
    }

    private func sponsorRecapRow(_ cart: CartManager.SponsorCart) -> some View {
        let sponsor = VioConfiguration.shared.sponsor(withId: cart.sponsorId)
        let logoUrl = sponsor?.avatarUrl ?? sponsor?.logoUrl
        let name = sponsor?.name ?? "Sponsor #\(cart.sponsorId)"
        let total = cart.subtotal + cart.shippingTotal
        return HStack(spacing: VioSpacing.md) {
            Group {
                if let logoStr = logoUrl, let url = URL(string: logoStr) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fit)
                        } else { Color.white.opacity(0.06) }
                    }
                } else {
                    Color.white.opacity(0.06)
                        .overlay(
                            Text(String(name.prefix(2)).uppercased())
                                .font(VioTypography.caption2.weight(.bold))
                                .foregroundColor(VioColors.textSecondary)
                        )
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(VioTypography.body.weight(.semibold))
                    .foregroundColor(VioColors.textPrimary)
                HStack(spacing: 4) {
                    Circle().fill(VioColors.success).frame(width: 5, height: 5)
                    Text("Order confirmed")
                        .font(VioTypography.caption2)
                        .foregroundColor(VioColors.success)
                }
            }
            Spacer()
            Text(formatMoney(total, code: cart.currency))
                .font(VioTypography.body.weight(.semibold))
                .foregroundColor(VioColors.textPrimary)
        }
        .padding(VioSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                .fill(VioColors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                .stroke(VioColors.border, lineWidth: 1)
        )
    }

    private var grandTotalCard: some View {
        // Grand-total is a sum across sponsor carts. Currency-mix
        // safety: we use the first cart's currency as label. If carts
        // span multiple currencies the host needs to handle that
        // separately (true for TV2 NO-only today).
        let total = paidSponsorCarts.reduce(0.0) { $0 + $1.subtotal + $1.shippingTotal }
        let currency = paidSponsorCarts.first?.currency ?? "USD"
        return HStack {
            Text("Grand total paid")
                .font(VioTypography.body.weight(.semibold))
                .foregroundColor(VioColors.textPrimary)
            Spacer()
            Text(formatMoney(total, code: currency))
                .font(VioTypography.title3.weight(.bold))
                .foregroundColor(VioColors.primary)
        }
        .padding(VioSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                .fill(VioColors.primary.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                .stroke(VioColors.primary.opacity(0.35), lineWidth: 1)
        )
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Text("Close")
                .font(VioTypography.body.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                        .fill(VioColors.primary)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, VioSpacing.lg)
        .padding(.bottom, VioSpacing.md)
    }

    private func formatMoney(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(code) \(value)"
    }
}
