//
//  NewsView.swift
//  Vg
//
//  Live news feed pulled from VG's public RSS, rendered with the same
//  visual rhythm as the vg.no app: pinned top bar, split hero, full-width
//  hero, 2x2 grids, SISTE NYTT compact list, ad/CTA banners. Tapping a
//  card calls onArticleTap so the host can route to a detail view (the
//  product carousel for the demo lives there, not in the feed).
//

import SwiftUI
import VioCore
import VioUI

struct NewsView: View {
    @StateObject private var viewModel = VGNewsFeedViewModel()
    /// Observe Vio config so the teaser re-renders the moment the SDK
    /// bootstrap (`/v2/mobile/config`) finishes and `primarySponsor`
    /// becomes non-nil — no manual refresh needed.
    @ObservedObject private var vioConfig = VioConfiguration.shared
    var onArticleTap: ((VGNewsArticle) -> Void)?
    /// Called when the Maxbo advertorial teaser is tapped. The host
    /// (VGHomeView) presents the article view with a horizontal push.
    var onMaxboArticleTap: (() -> Void)?
    /// Vev Design Test article (WKWebView + open-product deep links).
    var onVevDesignTestTap: (() -> Void)?

    /// Resolve the sponsor logo URL for the in-feed advertorial badge.
    /// Prefer the wide horizontal logo (`logoUrl`) over the square avatar,
    /// since the badge is a wider rectangle. Falls back to avatar if logo
    /// is missing or the URL is unparseable.
    private var sponsorLogoURL: URL? {
        let sponsor = vioConfig.primarySponsor
        let candidate = sponsor?.logoUrl ?? sponsor?.avatarUrl
        return candidate.flatMap { URL(string: $0) }
    }

    var body: some View {
        ZStack {
            // Page background — the darkest tone (#1C0000). Cards sit on
            // top with `Colors.burgundy` (#320000) so card edges are
            // visible against this layer.
            VGTheme.Colors.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                VGNewsTopBar()

                if viewModel.isLoading && viewModel.articles.isEmpty {
                    loadingState
                } else if let err = viewModel.loadError, viewModel.articles.isEmpty {
                    errorState(err)
                } else {
                    feedContent
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
    }

    // MARK: - Content sections

    /// Vertical breathing room between feed sections. Single source of
    /// truth so the grid (irregular by design) still reads as ordered.
    private let sectionGap: CGFloat = 10
    /// Internal gap between cards inside a 2x2 LazyVGrid (both row and
    /// column). Slightly larger than `sectionGap / 2` so a 2x2 block reads
    /// as one cohesive unit but each card still has a clear edge.
    private let gridGap: CGFloat = 6

    private var feedContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let split = viewModel.splitHero {
                    VGNewsHeroSplitCard(article: split) { tap(split) }
                }

                if let big = viewModel.bigHero {
                    Spacer().frame(height: sectionGap)
                    VGNewsHeroCard(article: big) { tap(big) }
                }

                if !viewModel.firstGrid.isEmpty {
                    Spacer().frame(height: sectionGap)
                    grid(viewModel.firstGrid)
                }

                Spacer().frame(height: sectionGap)
                VGAnnonseTeaserCard(
                    imageURL: URL(string: "https://cdn.vev.design/cdn-cgi/image/f=auto,q=82,h=1920/private/1pf9ZywbSqclWs0r8IjCFrrptpU2/image/2vDTdnW-OF.jpg"),
                    kicker: "Fra idé til ferdig møbel:",
                    headline: "Alt du trenger til verktøykassen",
                    brandLogoURL: sponsorLogoURL,
                    brandFallback: vioConfig.primarySponsor?.name ?? "Annonse"
                ) {
                    onMaxboArticleTap?()
                }

                vevDesignTestLink

                if !viewModel.sisteNytt.isEmpty {
                    Spacer().frame(height: sectionGap + 4)
                    VGNewsSectionHeader(title: "Siste nytt")
                    ForEach(viewModel.sisteNytt) { item in
                        VGNewsListItem(article: item) { tap(item) }
                    }

                    HStack {
                        Button {
                            // No-op for the demo. Tapping "Vis flere" could
                            // expand the list later — keeping it visual.
                        } label: {
                            HStack(spacing: 6) {
                                Text("Vis flere")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule().fill(VGTheme.Colors.burgundyDeep)
                            )
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                Spacer().frame(height: sectionGap + 6)

                VGTipsOssBanner()

                Spacer().frame(height: sectionGap + 6)

                if !viewModel.secondGrid.isEmpty {
                    grid(viewModel.secondGrid)
                }

                Spacer().frame(height: sectionGap + 6)

                // SDK-driven product store grid — bound to the campaign 38
                // placement `home_store` (cc 118 → 4 Maxbo/Weber products).
                // Wrapped in a white surface so it visually breaks from the
                // burgundy news feed, mirroring how vg.no presents inline
                // shop blocks. TODO (backend): expose `backgroundColor` and
                // padding via `app_placements.custom_config` so the
                // operator can drive this from the dashboard rather than
                // hard-coding it in the host app.
                VProductStore(locationId: "home_store")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color.white)

                if let trailing = viewModel.trailingHero {
                    Spacer().frame(height: sectionGap + 6)
                    VGNewsHeroCard(article: trailing) { tap(trailing) }
                }

                // Tail spacer so the floating cart indicator + bottom nav
                // (whatever the host overlays) don't crop the last card.
                Spacer().frame(height: 120)
            }
        }
        // ScrollView fills with the darker `pageBackground` so the gaps
        // between cards (`sectionGap`, `gridGap`, etc.) read as visible
        // separators against the lighter card surface (`burgundy`).
        // Previously this used `burgundy` which made the gaps invisible
        // (cards visually merged).
        .background(VGTheme.Colors.pageBackground)
    }

    // MARK: - Vev Design Test entry

    private var vevDesignTestLink: some View {
        Button {
            onVevDesignTestTap?()
        } label: {
            Text("VEV Design Test")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .underline()
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: - 2x2 grid helper

    private func grid(_ items: [VGNewsArticle]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: gridGap),
            GridItem(.flexible(), spacing: gridGap)
        ]
        return LazyVGrid(columns: columns, spacing: gridGap) {
            ForEach(items) { item in
                VGNewsGridCard(article: item) { tap(item) }
            }
        }
    }

    // MARK: - Empty / error / loading states

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
            Text("Laster nyheter…")
                .font(.system(size: 14))
                .foregroundColor(VGTheme.Colors.kickerMuted)
                .padding(.top, 12)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ msg: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(VGTheme.Colors.brandRed)
            Text("Kunne ikke laste nyheter")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text(msg)
                .font(.system(size: 12))
                .foregroundColor(VGTheme.Colors.kickerMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Prøv igjen") {
                Task { await viewModel.load() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(VGTheme.Colors.brandRed))
            .foregroundColor(.white)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Tap

    private func tap(_ article: VGNewsArticle) {
        onArticleTap?(article)
    }
}

#Preview {
    NewsView()
}
