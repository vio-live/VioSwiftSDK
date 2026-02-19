import SwiftUI
import Combine

/// Manager para simular el estado de casting
class CastingManager: ObservableObject {
    static let shared = CastingManager()
    
    @Published var isCasting: Bool = false
    @Published var selectedDevice: CastDevice?
    @Published var isConnecting: Bool = false
    
    // Dispositivos disponibles simulados
    let availableDevices = [
        CastDevice(id: "1", name: "Living TV", type: .chromecast, location: "Kolbotn - Nordstrand 2"),
        CastDevice(id: "2", name: "Cocina Display", type: .airplay, location: nil),
        CastDevice(id: "3", name: "Bedroom TV", type: .chromecast, location: nil)
    ]
    
    private init() {}
    
    func startCasting(to device: CastDevice) {
        isConnecting = true
        
        // Simular delay de conexión
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.selectedDevice = device
            self?.isCasting = true
            self?.isConnecting = false
        }
    }
    
    func stopCasting() {
        isCasting = false
        selectedDevice = nil
        isConnecting = false
    }
}

struct CastDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let type: CastDeviceType
    let location: String?
}

enum CastDeviceType {
    case chromecast
    case airplay
    
    var icon: String {
        switch self {
        case .chromecast: return "tv"
        case .airplay: return "airplayvideo"
        }
    }
}

