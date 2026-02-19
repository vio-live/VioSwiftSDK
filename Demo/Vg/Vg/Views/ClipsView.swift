//
//  ClipsView.swift
//  Vg
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI

struct ClipsView: View {
    var body: some View {
        VStack {
            Text("Klipp")
                .font(.title)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VGTheme.Colors.black)
    }
}

#Preview {
    ClipsView()
}
