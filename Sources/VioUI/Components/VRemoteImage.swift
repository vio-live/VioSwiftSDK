import SwiftUI

#if os(iOS)
import UIKit
import WebKit
#endif

/// Format-agnostic remote image renderer.
///
/// Routes:
///   - `.svg` URLs → `WKWebView` (SwiftUI's `AsyncImage` cannot decode SVG)
///   - everything else (PNG / JPEG / WebP / etc.) → `AsyncImage`
///
/// Used by placement views (`VProductCarousel`, `VProductSpotlight`,
/// future `VProductBanner` / etc.) for sponsor logos. Sponsors often
/// upload SVG as their primary logo (vector, scales cleanly across
/// densities). Without an SVG fallback the header would silently render
/// an empty space.
///
/// Public so any host-app view that wants the same fallback behavior
/// (e.g. a custom header outside the placement library) can reuse it.
///
/// Sprint 2026-04-28 PM (originally inline in VProductCarousel; extracted
/// to a shared file when VProductSpotlight needed the same fallback).
/// iOS-only path — Apple TV / tvOS renders are out of scope; on those
/// platforms the SVG branch returns an empty view, callers should
/// guard with `#if os(iOS)` or supply a raster fallback at the data
/// layer (e.g. prefer `sponsor.avatarUrl` when running on tvOS).
public struct VRemoteImage: View {
    private let urlString: String
    private let height: CGFloat

    public init(urlString: String, height: CGFloat) {
        self.urlString = urlString
        self.height = height
    }

    public var body: some View {
        guard let url = URL(string: urlString) else {
            return AnyView(EmptyView())
        }
        let isSvg = url.pathExtension.lowercased() == "svg"
        if isSvg {
            #if os(iOS)
            return AnyView(VSVGWebView(url: url).frame(height: height))
            #else
            return AnyView(EmptyView())
            #endif
        } else {
            return AnyView(
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        Color.clear
                    }
                }
                .frame(height: height)
            )
        }
    }
}

#if os(iOS)
/// Minimal `WKWebView` wrapper that loads a single SVG URL into a
/// transparent, non-scrollable web view sized to its container. Used
/// internally by `VRemoteImage`.
///
/// HTML wrapper centers the image vertically and aligns it to the
/// right (matches the placement-header "logo on the right" layout).
/// Scaled `height: 100%` so the SVG fits the container without
/// overflow on any density.
private struct VSVGWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!doctype html>
        <html><head><meta name='viewport' content='width=device-width, initial-scale=1.0'>
        <style>
          html, body { margin: 0; padding: 0; height: 100%; background: transparent; }
          body { display: flex; align-items: center; justify-content: flex-end; }
          img { height: 100%; width: auto; max-width: 100%; }
        </style></head>
        <body><img src='\(url.absoluteString)'/></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
#endif
