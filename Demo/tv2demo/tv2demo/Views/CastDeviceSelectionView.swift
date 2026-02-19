import SwiftUI

/// Vista para seleccionar dispositivo de casting (estilo TV2)
struct CastDeviceSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var castingManager = CastingManager.shared
    let onDeviceSelected: (CastDevice) -> Void
    
    var body: some View {
        ZStack {
            Color(hex: "1C1C1E")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("Cast to")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .frame(height: 56)
                .background(Color(hex: "2C2C2E"))
                .overlay(
                    HStack {
                        Spacer()
                        Button("Cancel") {
                            dismiss()
                        }
                        .font(.system(size: 17))
                        .foregroundColor(Color(hex: "0A84FF"))
                        .padding(.trailing, 16)
                    }
                )
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Lista de dispositivos
                VStack(spacing: 0) {
                    ForEach(castingManager.availableDevices) { device in
                        deviceRow(device)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private func deviceRow(_ device: CastDevice) -> some View {
        Button(action: {
            onDeviceSelected(device)
            dismiss()
        }) {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Icon
                    Image(systemName: device.type.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                    
                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(device.name)
                            .font(.system(size: 17))
                            .foregroundColor(.white)
                        
                        if let location = device.location {
                            Text("Casting: \(location)")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "8E8E93"))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(hex: "2C2C2E"))
                
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.leading, 80)
            }
        }
    }
}

#Preview {
    CastDeviceSelectionView { device in
        print("Selected: \(device.name)")
    }
}

