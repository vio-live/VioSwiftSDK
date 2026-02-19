//
//  LiveView.swift
//  Vg
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI

struct LiveView: View {
    var body: some View {
        VStack {
            Text("Direkte")
                .font(.title)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VGTheme.Colors.black)
    }
}

#Preview {
    LiveView()
}
