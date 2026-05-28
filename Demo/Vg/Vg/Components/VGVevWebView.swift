//
//  VGVevWebView.swift
//  Vg
//
//  Embeds a published Vev article and intercepts open-product deep links
//  (https://app…/open-product?id=… or vg://open-product?id=…).
//

import SwiftUI
import WebKit

private enum VGVevLog {
    static let prefix = "🧪 [VGVev]"

    static func info(_ message: String) {
        print("\(prefix) \(message)")
    }

    static func maskedApiKey(_ key: String?) -> String {
        guard let key, !key.isEmpty else { return "(app default)" }
        if key.count <= 4 { return "****" }
        return String(repeating: "*", count: max(0, key.count - 4)) + key.suffix(4)
    }
}

struct VGVevWebView: UIViewRepresentable {
    let url: URL
    var onOpenProduct: (VGVevOpenProductRequest) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpenProduct: onOpenProduct)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "vevLog")
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .white
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedURL != url else { return }
        context.coordinator.lastLoadedURL = url
        VGVevLog.info("Cargando artículo: \(url.absoluteString)")
        VGVevLog.info(
            "Esperando deep links → https://\(VGVevTestConfig.openProductHost)\(VGVevTestConfig.openProductPath)?id=<id>&apikey=<key>"
        )
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var lastLoadedURL: URL?
        let onOpenProduct: (VGVevOpenProductRequest) -> Void

        init(onOpenProduct: @escaping (VGVevOpenProductRequest) -> Void) {
            self.onOpenProduct = onOpenProduct
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            let target = navigationAction.request.url
            let navType = Self.navigationTypeLabel(navigationAction.navigationType)
            let mainFrame = navigationAction.targetFrame?.isMainFrame ?? true

            if let target {
                VGVevLog.info(
                    "Navegación [\(navType)] mainFrame=\(mainFrame) → \(target.absoluteString)"
                )
            } else {
                VGVevLog.info("Navegación [\(navType)] sin URL")
            }

            if let target,
               let request = VGVevURLRouting.openProductRequest(from: target, source: "decidePolicyFor") {
                VGVevLog.info(
                    "✅ callApp / open-product — productId=\(request.productId) apiKey=\(VGVevLog.maskedApiKey(request.apiKey))"
                )
                onOpenProduct(request)
                decisionHandler(.cancel)
                return
            }

            if let target, Self.looksLikeOpenProductAttempt(target) {
                VGVevLog.info(
                    "⚠️ URL parece open-product pero no pasó el filtro (revisa host/path en VGVevTestConfig)"
                )
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let target = navigationAction.request.url else {
                VGVevLog.info("createWebViewWith — sin URL")
                return nil
            }
            VGVevLog.info("createWebViewWith (target=_blank) → \(target.absoluteString)")

            if let request = VGVevURLRouting.openProductRequest(from: target, source: "createWebViewWith") {
                VGVevLog.info(
                    "✅ open-product (nueva ventana) — productId=\(request.productId) apiKey=\(VGVevLog.maskedApiKey(request.apiKey))"
                )
                onOpenProduct(request)
                return nil
            }
            webView.load(navigationAction.request)
            return nil
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            VGVevLog.info("didStartProvisionalNavigation → \(webView.url?.absoluteString ?? "nil")")
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            VGVevLog.info("✅ Artículo cargado: \(webView.url?.absoluteString ?? "nil")")
            VGVevLog.info("Toca un CTA en Vev; deberías ver «Navegación … open-product» al ejecutar callApp(id)")
            probeCallAppOnPage(webView)
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "vevLog" else { return }
            let body = String(describing: message.body)
            VGVevLog.info("[JS] \(body)")
        }

        /// Comprueba si `callApp` existe en el DOM de Vev tras cargar.
        private func probeCallAppOnPage(_ webView: WKWebView) {
            let script = """
            (function() {
                var hasCallApp = typeof callApp === 'function';
                var msg = hasCallApp
                    ? 'callApp() definido — listo para window.location.href open-product'
                    : 'callApp NO definido en window (¿publicaste el proyecto con el script?)';
                window.webkit.messageHandlers.vevLog.postMessage(msg);
                if (hasCallApp) {
                    try {
                        var src = String(callApp).substring(0, 200);
                        window.webkit.messageHandlers.vevLog.postMessage('callApp source (200 chars): ' + src);
                    } catch (e) {}
                }
                return hasCallApp;
            })();
            """
            webView.evaluateJavaScript(script) { result, error in
                if let error {
                    VGVevLog.info("[JS probe] evaluateJavaScript error: \(error.localizedDescription)")
                } else if let defined = result as? Bool {
                    VGVevLog.info("[JS probe] callApp definido = \(defined)")
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            VGVevLog.info("❌ didFail: \(error.localizedDescription)")
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            VGVevLog.info("❌ didFailProvisionalNavigation: \(error.localizedDescription)")
        }

        private static func navigationTypeLabel(_ type: WKNavigationType) -> String {
            switch type {
            case .linkActivated: return "linkActivated"
            case .formSubmitted: return "formSubmitted"
            case .backForward: return "backForward"
            case .reload: return "reload"
            case .formResubmitted: return "formResubmitted"
            case .other: return "other"
            @unknown default: return "unknown"
            }
        }

        /// Heuristic when Vev fires location.href but host/path no longer match config.
        private static func looksLikeOpenProductAttempt(_ url: URL) -> Bool {
            let absolute = url.absoluteString.lowercased()
            return absolute.contains("open-product")
                || absolute.contains("productid=")
                || absolute.contains("apikey=")
        }

    }
}

// MARK: - URL routing

enum VGVevURLRouting {
    /// Parses product id + apikey from Vev `callApp` deep links.
    static func openProductRequest(from url: URL, source: String = "routing") -> VGVevOpenProductRequest? {
        VGVevLog.info("[\(source)] parse URL scheme=\(url.scheme ?? "nil") host=\(url.host ?? "nil") path=\(url.path) query=\(url.query ?? "nil")")

        if let scheme = url.scheme?.lowercased(),
           scheme == VGVevTestConfig.openProductURLScheme.lowercased(),
           url.host?.lowercased() == "open-product" {
            return buildRequest(from: url, source: source, pathLabel: "vg://open-product")
        }

        let path = url.path.lowercased()
        let openPath = VGVevTestConfig.openProductPath.lowercased()
        guard path == openPath || path.hasSuffix(openPath) else {
            VGVevLog.info("[\(source)] path no es \(openPath) — ignorado")
            return nil
        }

        if !VGVevTestConfig.openProductHost.isEmpty {
            let host = (url.host ?? "").lowercased()
            let allowed = VGVevTestConfig.openProductHost.lowercased()
            guard host == allowed else {
                VGVevLog.info("[\(source)] host '\(host)' ≠ esperado '\(allowed)' — ignorado")
                return nil
            }
        }

        return buildRequest(from: url, source: source, pathLabel: "https open-product")
    }

    private static func buildRequest(from url: URL, source: String, pathLabel: String) -> VGVevOpenProductRequest? {
        guard let productId = queryProductId(url) else {
            VGVevLog.info("[\(source)] \(pathLabel) sin id en query (usa ?id=123)")
            return nil
        }
        let apiKey = queryApiKey(url)
        VGVevLog.info(
            "[\(source)] match \(pathLabel) id=\(productId) apiKey=\(VGVevLog.maskedApiKey(apiKey))"
        )
        return VGVevOpenProductRequest(productId: productId, apiKey: apiKey)
    }

    private static func queryItems(_ url: URL) -> [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    private static func queryProductId(_ url: URL) -> String? {
        for name in ["id", "productId", "product_id"] {
            if let value = queryItems(url).first(where: { $0.name == name })?.value,
               !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func queryApiKey(_ url: URL) -> String? {
        for item in queryItems(url) {
            let name = item.name.lowercased()
            guard ["apikey", "api_key"].contains(name),
                  let value = item.value,
                  !value.isEmpty else { continue }
            return value
        }
        return nil
    }
}
