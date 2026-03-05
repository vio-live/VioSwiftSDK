import Foundation
import Combine

/// Guarda el productId que llegó via push antes de que el SDK esté listo.
/// ContentView lo observa y abre el overlay cuando el SDK está READY.
@MainActor
class PushNavigationManager: ObservableObject {
    static let shared = PushNavigationManager()
    private init() {}

    @Published var pendingProductId: String? = nil

    func setPendingProduct(id: String) {
        print("📌 [PushNav] Guardando productId pendiente: \(id)")
        pendingProductId = id
    }

    func consume() -> String? {
        let id = pendingProductId
        pendingProductId = nil
        return id
    }
}
