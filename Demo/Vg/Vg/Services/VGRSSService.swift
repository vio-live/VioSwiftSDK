//
//  VGRSSService.swift
//  Vg
//
//  Fetches and parses VG's public RSS feed into [VGNewsArticle].
//  The feed lives at https://www.vg.no/rss/feed/?format=rss and uses
//  the `vg:` namespace for image URLs (`<vg:img>` / `<image>` / `<enclosure>`).
//

import Foundation

// MARK: - Model

/// Article parsed from VG's public RSS feed.
/// Defined here (rather than a standalone file) to keep Xcode's
/// PBXFileSystemSynchronizedRootGroup happy — moving Swift files between
/// directories sometimes confuses the IDE's sync state. Co-locating with
/// the producer avoids it.
struct VGNewsArticle: Identifiable, Equatable {
    let id: String        // <guid>
    let rawTitle: String  // raw <title> content (kicker + headline still glued)
    let description: String?
    let link: URL
    let pubDate: Date
    let imageURL: URL?
    let category: String? // Nyheter / Sport / Rampelys / E24 …

    /// VG glues a kicker into <title> with `:` as separator, e.g.
    /// `"Ekspert om Trump: – USA har tabbet seg ut"`. We split it
    /// at the first `:` and strip a leading `– ` / `- ` from the headline.
    var split: (kicker: String?, headline: String) {
        Self.splitKicker(rawTitle)
    }

    var kicker: String? { split.kicker }
    var headline: String { split.headline }

    /// "23 min", "2 t", "i går" — VG-style relative timestamp for
    /// the SISTE NYTT list. Norwegian-locale-friendly.
    var relativeTime: String {
        let now = Date()
        let interval = now.timeIntervalSince(pubDate)
        let minutes = Int(interval / 60)
        if minutes < 1 { return "nå" }
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) t" }
        let days = hours / 24
        if days == 1 { return "i går" }
        return "\(days) d"
    }

    static func splitKicker(_ title: String) -> (kicker: String?, headline: String) {
        guard let colonIdx = title.firstIndex(of: ":") else {
            return (nil, title)
        }
        let kicker = String(title[..<colonIdx]) + ":"
        var headline = title[title.index(after: colonIdx)...]
            .trimmingCharacters(in: .whitespaces)
        // VG often prefixes the headline with an en dash: "– foo" or "- foo"
        if headline.hasPrefix("– ") || headline.hasPrefix("- ") {
            headline = String(headline.dropFirst(2))
                .trimmingCharacters(in: .whitespaces)
        }
        // Sanity: if the headline ends up empty (rare), fall back to raw title
        if headline.isEmpty {
            return (nil, title)
        }
        return (kicker, headline)
    }
}

// MARK: - Errors

enum VGRSSError: Error {
    case invalidURL
    case network(Error)
    case parseFailed
}

final class VGRSSService {
    static let shared = VGRSSService()
    private init() {}

    static let feedURL = URL(string: "https://www.vg.no/rss/feed/?format=rss")!

    func fetchArticles() async throws -> [VGNewsArticle] {
        do {
            let (data, _) = try await URLSession.shared.data(from: Self.feedURL)
            let parser = VGRSSParser()
            return try parser.parse(data: data)
        } catch {
            throw VGRSSError.network(error)
        }
    }
}

/// XMLParserDelegate that walks the RSS document and accumulates `<item>`s.
/// Kept private to the service — call `VGRSSService.shared.fetchArticles()`.
private final class VGRSSParser: NSObject, XMLParserDelegate {
    private var articles: [VGNewsArticle] = []
    private var inItem = false
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentLink = ""
    private var currentGuid = ""
    private var currentPubDate = ""
    private var currentCategory = ""
    // VG repeats the same image URL across <vg:img>, <vg:articleImg>,
    // <image>, <imgRegular> and an <enclosure url=…> attribute. We keep
    // one buffer per element so they don't concatenate, then pick the
    // first non-empty one when the item closes.
    private var currentVgImg = ""
    private var currentVgArticleImg = ""
    private var currentImage = ""
    private var currentImgRegular = ""
    private var currentEnclosureURL = ""

    /// RSS uses RFC 822 date format, e.g. "Wed, 06 May 2026 16:10:54 GMT".
    private static let rfc822: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()

    func parse(data: Data) throws -> [VGNewsArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            throw VGRSSError.parseFailed
        }
        return articles
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName

        if elementName == "item" {
            inItem = true
            currentTitle = ""
            currentDescription = ""
            currentLink = ""
            currentGuid = ""
            currentPubDate = ""
            currentCategory = ""
            currentVgImg = ""
            currentVgArticleImg = ""
            currentImage = ""
            currentImgRegular = ""
            currentEnclosureURL = ""
        }

        if inItem, elementName == "enclosure", let url = attributeDict["url"] {
            currentEnclosureURL = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title":       currentTitle.append(string)
        case "description": currentDescription.append(string)
        case "link":        currentLink.append(string)
        case "guid":        currentGuid.append(string)
        case "pubDate":     currentPubDate.append(string)
        case "category":    currentCategory.append(string)
        case "vg:img":          currentVgImg.append(string)
        case "vg:articleImg":   currentVgArticleImg.append(string)
        case "image":           currentImage.append(string)
        case "imgRegular":      currentImgRegular.append(string)
        default: break
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "item" {
            inItem = false
            // Build the article — skip if we don't even have a guid+title+link.
            let trimmedTitle = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedGuid = currentGuid.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty,
                  !trimmedGuid.isEmpty,
                  let linkURL = URL(string: trimmedLink) else {
                return
            }

            // Pick the first non-empty image source we collected. Each
            // candidate has its own buffer so they never concatenate.
            let imageString = [
                currentVgImg,
                currentVgArticleImg,
                currentImage,
                currentImgRegular,
                currentEnclosureURL
            ]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
            let imageURL = imageString.isEmpty ? nil : URL(string: imageString)

            // Date: best-effort — if it doesn't parse, fall back to "now"
            // so the article still shows up rather than getting dropped.
            let date = Self.rfc822.date(
                from: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)
            ) ?? Date()

            let descTrim = currentDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryTrim = currentCategory.trimmingCharacters(in: .whitespacesAndNewlines)

            articles.append(
                VGNewsArticle(
                    id: trimmedGuid,
                    rawTitle: trimmedTitle,
                    description: descTrim.isEmpty ? nil : descTrim,
                    link: linkURL,
                    pubDate: date,
                    imageURL: imageURL,
                    category: categoryTrim.isEmpty ? nil : categoryTrim
                )
            )
        }
        currentElement = ""
    }
}
