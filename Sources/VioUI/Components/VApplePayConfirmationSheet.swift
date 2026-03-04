import SwiftUI
import PassKit
import VioCore

/// Confirmation sheet shown after a successful Apple Pay payment
public struct VApplePayConfirmationSheet: View {

    let productName: String
    let productImageUrl: String?
    let priceNOK: Double
    let contact: PKContact?
    let onDismiss: () -> Void

    // Sponsor logo pulled from CampaignManager
    private var sponsorLogoUrl: String? {
        VioConfiguration.shared.sponsorConfig?.logoUrl
    }

    @State private var appeared = false

    public var body: some View {
        VStack(spacing: 0) {
                    // Handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 40, height: 4)
                        .padding(.top, 16)
                        .padding(.bottom, 20)

                    // Success icon
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.44, green: 0.0, blue: 1.0).opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(Color(red: 0.44, green: 0.0, blue: 1.0))
                    }
                    .padding(.bottom, 16)

                    // Sponsor logo (top right of success icon)
                    if let logoStr = sponsorLogoUrl, let logoUrl = URL(string: logoStr) {
                        HStack {
                            Spacer()
                            AsyncImage(url: logoUrl) { phase in
                                if case .success(let img) = phase {
                                    img.resizable().aspectRatio(contentMode: .fit)
                                } else { EmptyView() }
                            }
                            .frame(height: 22)
                            .padding(.trailing, 20)
                            .padding(.bottom, 4)
                        }
                    }

                    Text("Betaling godkjent")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text("Takk for kjøpet!")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 28)

                    // Order card
                    VStack(spacing: 0) {
                        // Product row
                        HStack(spacing: 14) {
                            // Product image
                            if let urlStr = productImageUrl, let url = URL(string: urlStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().aspectRatio(contentMode: .fill)
                                    default:
                                        Color.white.opacity(0.1)
                                    }
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        Image(systemName: "shippingbox")
                                            .foregroundColor(.white.opacity(0.4))
                                    )
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(productName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)

                                Text("1 stk")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            Spacer()

                            Text(formatNOK(priceNOK))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(16)

                        Divider().background(Color.white.opacity(0.1))

                        // Subtotal row
                        HStack {
                            Text("Subtotal")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                            Spacer()
                            Text(formatNOK(priceNOK))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().background(Color.white.opacity(0.1))

                        // Shipping address
                        if let addr = shippingLine {
                            HStack(alignment: .top) {
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contactName ?? "")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(addr)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                } icon: {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(Color(red: 0.44, green: 0.0, blue: 1.0))
                                        .font(.system(size: 18))
                                }
                                Spacer()
                            }
                            .padding(16)
                        }
                    }
                    .background(Color.white.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                    // CTA
                    Button(action: onDismiss) {
                        Text("Lukk")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.44, green: 0.0, blue: 1.0))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(red: 0.44, green: 0.0, blue: 1.0).opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                }
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                )
        .onAppear { appeared = true }
    }

    // MARK: - Helpers
    private var contactName: String? {
        guard let n = contact?.name else { return nil }
        return [n.givenName, n.familyName].compactMap { $0 }.joined(separator: " ")
    }

    private var shippingLine: String? {
        guard let addr = contact?.postalAddress else { return nil }
        return "\(addr.street), \(addr.postalCode) \(addr.city)"
    }

    private func formatNOK(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "NOK"
        formatter.currencySymbol = "kr"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "kr \(Int(amount))"
    }
}
