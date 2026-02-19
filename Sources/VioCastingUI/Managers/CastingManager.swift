//
//  CastingManager.swift
//  VioCastingUI
//
//  Demo casting state manager for simulating cast-to-TV behavior.
//  In production, replace with real AirPlay/Chromecast SDK integration.
//

import SwiftUI
import Combine

/// Manager for simulating casting state in demo
public class CastingManager: ObservableObject {
    public static let shared = CastingManager()
    
    @Published public var isCasting: Bool = false
    @Published public var selectedDevice: CastDevice?
    @Published public var isConnecting: Bool = false
    
    public let availableDevices = [
        CastDevice(id: "1", name: "Living TV", type: .chromecast, location: "Kolbotn - Nordstrand 2"),
        CastDevice(id: "2", name: "Cocina Display", type: .airplay, location: nil),
        CastDevice(id: "3", name: "Bedroom TV", type: .chromecast, location: nil)
    ]
    
    private init() {}
    
    public func startCasting(to device: CastDevice) {
        isConnecting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.selectedDevice = device
            self?.isCasting = true
            self?.isConnecting = false
        }
    }
    
    public func stopCasting() {
        isCasting = false
        selectedDevice = nil
        isConnecting = false
    }
}

public struct CastDevice: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let type: CastDeviceType
    public let location: String?
}

public enum CastDeviceType {
    case chromecast
    case airplay
    
    public var icon: String {
        switch self {
        case .chromecast: return "tv"
        case .airplay: return "airplayvideo"
        }
    }
}
