# Vio Swift SDK

A modular Swift SDK for the Vio platform. Add live engagement, commerce, and shoppable experiences to any iOS application.

## 🏗️ Modular Architecture

Import only what you need:

| Module | Description |
|--------|-------------|
| **VioCore** | Core models, configuration, and business logic (required) |
| **VioUI** | SwiftUI commerce components (product cards, cart, checkout) |
| **VioLiveShow** | Live stream logic and data models |
| **VioLiveUI** | Live stream UI components (overlays, mini-player) |
| **VioDesignSystem** | Design tokens and base components |
| **VioEngagementSystem** | Polls, contests, and engagement logic |
| **VioEngagementUI** | Engagement UI components |

## 📦 Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/angelosv/VioSwiftSDK.git", from: "0.1.0")
]
```

Or in Xcode: **File → Add Package Dependencies** → enter the URL above.

### Module selection

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "VioCore", package: "VioSwiftSDK"),
        .product(name: "VioEngagementUI", package: "VioSwiftSDK"),
        // add more modules as needed
    ]
)
```

## 🚀 Quick Start

```swift
import SwiftUI
import VioCore
import VioEngagementUI

@main
struct YourApp: App {
    init() {
        // Load configuration (vio-config.json in your app bundle)
        ConfigurationLoader.loadConfiguration()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

The SDK connects automatically to your active broadcast via WebSocket and renders polls, contests, and shoppable product cards in real time — no app update required to change sponsor, product, or engagement content.

## 📋 Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15+

## 📚 Documentation

Full documentation at **[docs.vio.live](https://docs.vio.live)**

## 📄 License

MIT License
