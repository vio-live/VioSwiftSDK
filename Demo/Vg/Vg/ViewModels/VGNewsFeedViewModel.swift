//
//  VGNewsFeedViewModel.swift
//  Vg
//
//  Pulls the RSS feed and slots the articles into the visual buckets that
//  the VG layout expects: a top split-hero, a giant hero, two 2x2 grids,
//  one SISTE NYTT compact list, and a couple of inline ad/CTA banners.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class VGNewsFeedViewModel: ObservableObject {
    @Published private(set) var articles: [VGNewsArticle] = []
    @Published private(set) var isLoading = false
    @Published private(set) var loadError: String?

    /// First article is the split-hero (small image + headline) at the top of the feed.
    var splitHero: VGNewsArticle? {
        articlesWithImage.first
    }

    /// Second article is the giant full-width hero.
    var bigHero: VGNewsArticle? {
        let withImage = articlesWithImage
        return withImage.count > 1 ? withImage[1] : nil
    }

    /// Articles 3-6 (image required) form the first 2x2 grid.
    var firstGrid: [VGNewsArticle] {
        let withImage = articlesWithImage
        guard withImage.count > 2 else { return [] }
        let start = 2
        let end = min(start + 4, withImage.count)
        return Array(withImage[start..<end])
    }

    /// Up to 5 articles for the SISTE NYTT compact list — image is optional here.
    var sisteNytt: [VGNewsArticle] {
        // Use everything we have, skip whatever's already on top, keep the next 5.
        let consumedIDs = Set([
            splitHero?.id,
            bigHero?.id
        ].compactMap { $0 } + firstGrid.map(\.id))
        let remaining = articles.filter { !consumedIDs.contains($0.id) }
        return Array(remaining.prefix(5))
    }

    /// Articles after SISTE NYTT, image required, for the second 2x2 grid.
    var secondGrid: [VGNewsArticle] {
        let consumedIDs = Set([
            splitHero?.id,
            bigHero?.id
        ].compactMap { $0 } + firstGrid.map(\.id) + sisteNytt.map(\.id))
        let remaining = articlesWithImage.filter { !consumedIDs.contains($0.id) }
        return Array(remaining.prefix(4))
    }

    /// One trailing big hero after the second grid, if we have anything left.
    var trailingHero: VGNewsArticle? {
        let consumedIDs = Set([
            splitHero?.id,
            bigHero?.id
        ].compactMap { $0 } + firstGrid.map(\.id) + sisteNytt.map(\.id) + secondGrid.map(\.id))
        return articlesWithImage.first { !consumedIDs.contains($0.id) }
    }

    private var articlesWithImage: [VGNewsArticle] {
        articles.filter { $0.imageURL != nil }
    }

    func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let fresh = try await VGRSSService.shared.fetchArticles()
            articles = fresh
        } catch {
            loadError = String(describing: error)
        }
    }
}
