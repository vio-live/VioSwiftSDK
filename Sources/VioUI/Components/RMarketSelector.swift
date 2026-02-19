import VioCore
import VioDesignSystem
import SwiftUI

/// Vio Market Selector Component
///
/// Displays the list of available markets and allows the user to switch
/// currency, country and phone prefix based on the selected market.
public struct RMarketSelector: View {

    @EnvironmentObject private var cartManager: CartManager
    @Environment(\.colorScheme) private var colorScheme

    private var adaptiveColors: AdaptiveColors {
        VioColors.adaptive(for: colorScheme)
    }

    public init() {}
    
    private var fallbackFlagURL: String? {
        VioConfiguration.shared.marketConfiguration.flagURL
    }

    private var orderedMarkets: [CartManager.Market] {
        guard let selected = cartManager.selectedMarket,
              let index = cartManager.markets.firstIndex(of: selected) else {
            return cartManager.markets
        }

        var markets = cartManager.markets
        let selectedMarket = markets.remove(at: index)
        markets.insert(selectedMarket, at: 0)
        return markets
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: VioSpacing.sm) {
            Text("Market & Currency")
                .font(VioTypography.headline)
                .foregroundColor(adaptiveColors.textPrimary)
                .padding(.horizontal, VioSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VioSpacing.sm) {
                    ForEach(orderedMarkets) { market in
                        MarketChip(
                            market: market,
                            fallbackFlagURL: fallbackFlagURL,
                            isSelected: cartManager.selectedMarket?.id == market.id
                        ) {
                            Task {
                                await cartManager.selectMarket(market)
                            }
                        }
                    }
                }
                .padding(.horizontal, VioSpacing.lg)
            }
        }
        .task {
            await cartManager.loadMarketsIfNeeded()
        }
    }
}

private struct MarketChip: View {
    let market: CartManager.Market
    let fallbackFlagURL: String?
    let isSelected: Bool
    let action: () -> Void
    
    private var resolvedFlagURL: String? {
        market.flagURL ?? fallbackFlagURL
    }

    private var placeholderFlag: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(VioColors.surfaceSecondary)
            .overlay(
                Text(market.code.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(VioColors.textSecondary)
            )
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: VioSpacing.xs) {
                Group {
                    if let flagURL = resolvedFlagURL, let url = URL(string: flagURL) {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                placeholderFlag
                            }
                        }
                    } else {
                        placeholderFlag
                    }
                }
                .frame(width: 24, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 3))

                VStack(alignment: .leading, spacing: 2) {
                    Text(market.name)
                        .font(VioTypography.caption1)
                        .foregroundColor(isSelected ? Color.white : VioColors.textPrimary)
                        .lineLimit(1)

                    Text("\(market.currencySymbol) • \(market.currencyCode)")
                        .font(VioTypography.caption2)
                        .foregroundColor(isSelected ? Color.white.opacity(0.9) : VioColors.textSecondary)
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            }
            .padding(.horizontal, VioSpacing.md)
            .padding(.vertical, VioSpacing.sm)
            .background(
                isSelected ? VioColors.primary : VioColors.surfaceSecondary
            )
            .overlay(
                RoundedRectangle(cornerRadius: VioBorderRadius.medium)
                    .stroke(isSelected ? Color.clear : VioColors.border, lineWidth: 1)
            )
            .cornerRadius(VioBorderRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
