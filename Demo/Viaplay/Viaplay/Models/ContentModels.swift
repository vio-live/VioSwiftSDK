//
//  ContentModels.swift
//  Viaplay
//
//  Created by Angelo Sepulveda on 27/10/2025.
//

import Foundation

struct HeroContent {
    let id = UUID()
    let title: String
    let description: String
    let imageUrl: String
    let hasCrown: Bool
}

struct ContinueWatchingItem: Identifiable {
    let id = UUID()
    let title: String
    let imageUrl: String
    let rentLabel: String?
    let progress: Double
}

// MARK: - Mock Data
extension HeroContent {
    static let mock: HeroContent = HeroContent(
        title: "You Can't Run Forever",
        description: "Omfavn frykten, finn styrke og overlev jakten. Med Oscar-vinner J.K. Simmons.",
        imageUrl: "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=800",
        hasCrown: true
    )
}

extension ContinueWatchingItem {
    static let mockItems: [ContinueWatchingItem] = [
        ContinueWatchingItem(
            title: "E.T. the Extra-Terrestrial",
            imageUrl: "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300",
            rentLabel: "Rent",
            progress: 0.25 // 25 min left
        ),
        ContinueWatchingItem(
            title: "Hotell Transylvania: Monsterferie",
            imageUrl: "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300",
            rentLabel: "Rent",
            progress: 0.10 // 10 min left
        ),
        ContinueWatchingItem(
            title: "The Boss Baby",
            imageUrl: "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300",
            rentLabel: nil,
            progress: 0.07 // 7 min left
        )
    ]
}
