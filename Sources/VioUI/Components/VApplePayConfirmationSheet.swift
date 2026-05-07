import SwiftUI
import VioCore

#if os(iOS)
import PassKit

/// Post–Apple Pay confirmation sheet (iOS).
///
/// All colors come from the active theme via `VioColors.adaptive(for:)`
/// so every host (TV2, Viaplay, Vg, future) gets its own palette
/// automatically. The accent (checkmark, pin icon, "Lukk" button) uses
/// `VioColors.primary` so it tracks the host's brand color (e.g. TV2
/// purple, VG red).
public struct VApplePayConfirmationSheet: View {

    @SwiftUI.Environment(\.colorScheme) private var colorScheme: SwiftUI.ColorScheme

    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }

    let productName: String
    let productImageUrl: String?
    let amount: Double
    let currencyCode: String
    let contact: PKContact?
    let sponsorId: Int?
    let onDismiss: () -> Void

    /// The sponsor that owns this purchase. Q4 (2026-04-30): callers now
    /// pass `sponsorId` explicitly through the call chain
    /// (VProductCard/Banner/Carousel/Spotlight → VProductDetailOverlay →
    /// VApplePayButton → this sheet). The previous global lookup
    /// (`CommerceSdkClientProvider.activeSponsorId`) is kept only as a
    /// last-resort fallback for legacy callsites that haven't yet been
    /// migrated; new callsites should always supply `sponsorId`.
    ///
    /// No fallback to campaign-level or host-app brand by design: if the
    /// resolved sponsor has no logo, the sheet renders without one
    /// (instead of showing the wrong brand).
    private var sponsorLogoUrl: String? {
        let resolvedId = sponsorId ?? CommerceSdkClientProvider.shared.activeSponsorId
        guard let id = resolvedId,
              let logo = VioConfiguration.shared.sponsor(withId: id)?.logoUrl,
              !logo.isEmpty else {
            return nil
        }
        return logo
    }

    public init(
        productName: String,
        productImageUrl: String?,
        amount: Double,
        currencyCode: String,
        contact: PKContact?,
        sponsorId: Int? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.productName = productName
        self.productImageUrl = productImageUrl
        self.amount = amount
        self.currencyCode = currencyCode
        self.contact = contact
        self.sponsorId = sponsorId
        self.onDismiss = onDismiss
    }

    public var body: some View {
        // Reusable adaptive references — host theme drives everything.
        let primary = VioColors.primary
        let textPrimary = adaptiveColors.textPrimary
        let textSecondary = adaptiveColors.textSecondary
        let textTertiary = adaptiveColors.textTertiary
        let surface = adaptiveColors.surface
        let surfaceSecondary = adaptiveColors.surfaceSecondary
        let border = adaptiveColors.border

        return VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(textTertiary.opacity(0.6))
                .frame(width: 40, height: 4)
                .padding(.top, 16)
                .padding(.bottom, 20)

            ZStack {
                Circle()
                    .fill(primary.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(primary)
            }
            .padding(.bottom, 16)

            if let logoStr = sponsorLogoUrl, let logoUrl = URL(string: logoStr) {
                HStack {
                    AsyncImage(url: logoUrl) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fit)
                        } else { EmptyView() }
                    }
                    .frame(height: 22)
                    .padding(.leading, 20)
                    .padding(.bottom, 4)
                    Spacer()
                }
            }

            Text("Betaling godkjent")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(textPrimary)

            Text("Takk for kjøpet!")
                .font(.system(size: 15))
                .foregroundColor(textSecondary)
                .padding(.bottom, 28)

            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    if let urlStr = productImageUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fill)
                            default:
                                surfaceSecondary
                            }
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(surfaceSecondary)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "shippingbox")
                                    .foregroundColor(textTertiary)
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(productName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(textPrimary)
                            .lineLimit(2)

                        Text("1 stk")
                            .font(.system(size: 13))
                            .foregroundColor(textSecondary)
                    }

                    Spacer()

                    Text(formatMoney(amount, code: currencyCode))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(textPrimary)
                }
                .padding(16)

                Divider().background(border)

                HStack {
                    Text("Subtotal")
                        .font(.system(size: 14))
                        .foregroundColor(textSecondary)
                    Spacer()
                    Text(formatMoney(amount, code: currencyCode))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider().background(border)

                if let addr = shippingLine {
                    HStack(alignment: .top) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contactName ?? "")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(textPrimary)
                                Text(addr)
                                    .font(.system(size: 13))
                                    .foregroundColor(textSecondary)
                            }
                        } icon: {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(primary)
                                .font(.system(size: 18))
                        }
                        Spacer()
                    }
                    .padding(16)
                }
            }
            .background(surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Button(action: onDismiss) {
                Text("Lukk")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(primary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 36)
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(surface)
        )
    }

    private var contactName: String? {
        guard let n = contact?.name else { return nil }
        return [n.givenName, n.familyName].compactMap { $0 }.joined(separator: " ")
    }

    private var shippingLine: String? {
        guard let addr = contact?.postalAddress else { return nil }
        return "\(addr.street), \(addr.postalCode) \(addr.city)"
    }

    private func formatMoney(_ value: Double, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(code) \(value)"
    }
}

#else

public struct VApplePayConfirmationSheet: View {
    public init(
        productName: String,
        productImageUrl: String?,
        amount: Double,
        currencyCode: String,
        contact: Any?,
        onDismiss: @escaping () -> Void
    ) {}

    public var body: some View { EmptyView() }
}

#endif
