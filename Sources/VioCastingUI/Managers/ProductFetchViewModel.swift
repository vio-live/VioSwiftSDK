//
//  ProductFetchViewModel.swift
//  VioCastingUI
//
//  ViewModel for fetching individual products from Vio API.
//  Used by product overlays in video player and casting views.
//

import Foundation
import SwiftUI
import Combine
import VioCore
import VioUI

/// ViewModel for fetching individual products from Vio API
@MainActor
public class ProductFetchViewModel: ObservableObject {
    @Published public var product: ProductDto?
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let sdk: SdkClient
    public var currency: String
    public var country: String
    
    public init(sdk: SdkClient, currency: String, country: String) {
        self.sdk = sdk
        self.currency = currency
        self.country = country
    }
    
    public func fetchProduct(productId: String) async {
        guard !productId.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        product = nil
        
        do {
            guard let productIdInt = Int(productId) else {
                self.errorMessage = "productId inválido: \(productId)"
                isLoading = false
                return
            }
            
            let products = try await sdk.product.getByIds(
                productIds: [productIdInt],
                currency: currency,
                imageSize: "large",
                useCache: false,
                shippingCountryCode: country
            )
            
            if let fetchedProduct = products.first {
                self.product = fetchedProduct
            } else {
                self.errorMessage = "Producto no encontrado"
            }
            
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    public func fetchProducts(ids: [String]) async {
        guard !ids.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let productIds = ids.compactMap { Int($0) }
            guard productIds.count == ids.count else {
                self.errorMessage = "Algunos IDs de producto son inválidos"
                isLoading = false
                return
            }
            
            let products = try await sdk.product.getByIds(
                productIds: productIds,
                currency: currency,
                imageSize: "large",
                useCache: false,
                shippingCountryCode: country
            )
            
            if let first = products.first {
                self.product = first
            }
            
            isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
