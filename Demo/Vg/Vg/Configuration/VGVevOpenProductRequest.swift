//
//  VGVevOpenProductRequest.swift
//  Vg
//
//  Parsed from Vev callApp URL:
//  https://app.midominio.com/open-product?id=…&apikey=…
//

import Foundation

struct VGVevOpenProductRequest: Equatable, Hashable {
    let productId: String
    /// API key from the article; when nil, fetch falls back to `VioConfiguration.shared.apiKey`.
    let apiKey: String?
}
