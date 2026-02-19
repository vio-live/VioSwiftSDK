//
//  NewsView.swift
//  Vg
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import SwiftUI

struct NewsView: View {
    var body: some View {
        VStack {
            Text("Nyheter")
                .font(.title)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VGTheme.Colors.black)
    }
}

#Preview {
    NewsView()
}
