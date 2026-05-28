//
//  VGVevTestConfig.swift
//  Vg
//
//  Demo-only knobs for the Vev Design Test article WebView.
//  Change `articleURL` when trying a new publish from editor.vev.design.
//

import Foundation

enum VGVevTestConfig {
    /// Published Vev article URL (Publish in editor.vev.design → public URL).
    static var articleURL: String = "https://a-alan-local.vev.site/test-m"

    /// Host used in Vev onclick links, e.g.
    /// `…/open-product?id=123&apikey=<campaignApiKey>`
    /// Leave empty to accept `/open-product` on any host (demo convenience).
    static var openProductHost: String = "app.midominio.com"

    static let openProductPath = "/open-product"

    /// Custom URL scheme fallback: `vg://open-product?id=123`
    static let openProductURLScheme = "vg"

    static var articleURLValue: URL? {
        URL(string: articleURL.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
