import SwiftUI
import VioCore
import VioUI

/// Sheet simple para abrir producto desde push notification.
/// Usa VProductDetailOverlay internamente pero con fallback visual.
struct PushProductSheet: View {
    let product: Product
    let onDismiss: () -> Void
    @EnvironmentObject var cartManager: CartManager

    var body: some View {
        VProductDetailOverlay(product: product, onDismiss: onDismiss)
            .environmentObject(cartManager)
            .onAppear { print("🔍 [PushProductSheet] appeared for product: \(product.title)") }
    }
}
