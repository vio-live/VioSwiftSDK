//
//  VGLiveView.swift
//  Vg
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI

struct VGLiveView: View {
    var body: some View {
        VStack {
            Text("VG Live")
                .font(.title)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VGTheme.Colors.black)
    }
}

#Preview {
    VGLiveView()
}
