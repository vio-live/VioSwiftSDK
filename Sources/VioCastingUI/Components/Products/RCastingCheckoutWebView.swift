//
//  CastingCheckoutWebView.swift
//  Viaplay
//
//  WebView component for displaying Casting checkout in an embedded view
//

import SwiftUI
import WebKit

struct CastingCheckoutWebView: UIViewRepresentable {
    let url: URL
    let onDismiss: () -> Void
    let onBack: (() -> Void)?
    @Binding var isLoading: Bool
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        let request = URLRequest(url: url)
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: CastingCheckoutWebView
        
        init(_ parent: CastingCheckoutWebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation
            decisionHandler(.allow)
        }
    }
}

// MARK: - SwiftUI Wrapper with Loading State

struct CastingCheckoutWebViewContainer: View {
    let url: URL
    let onDismiss: () -> Void
    let onBack: (() -> Void)?
    
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            CastingCheckoutWebView(
                url: url,
                onDismiss: onDismiss,
                onBack: onBack,
                isLoading: $isLoading
            )
            
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("Laster checkout...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.8))
            }
        }
    }
}
