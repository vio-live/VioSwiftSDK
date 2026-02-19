# Reachu Swift SDK

Note: Demos live in the separate repository `ReachuSwiftSDK-Demos`. Each demo depends on this SDK via SPM (by URL and version tag).

A modular Swift SDK for the Reachu ecommerce platform. Add shopping cart, checkout, and livestream features to any iOS, macOS, tvOS or watchOS application.

## 🏗️ Modular Architecture

This SDK is designed with a modular architecture that allows you to import only the features you need:

- **ReachuCore** (Required) - Core ecommerce functionality, models, and configuration
- **ReachuUI** (Optional) - SwiftUI ecommerce components (Product Cards, Sliders, Cart, Checkout)
- **ReachuLiveShow** (Optional) - Livestream shopping logic and data models
- **ReachuLiveUI** (Optional) - Livestream UI components (Video player, Chat, Shopping overlays)
- **ReachuComplete** (All-in-One) - All modules included

## 📦 Installation

### Swift Package Manager (Recommended)

Add the Reachu Swift SDK to your project using Swift Package Manager:

#### Using Xcode

1. **Open your Xcode project**
2. **Go to File → Add Package Dependencies...**
3. **Enter the repository URL:**
   ```
   https://github.com/ReachuDevteam/ReachuSwiftSDK.git
   ```
4. **Select the version**: `1.0.0` (or latest version)
5. **Choose your modules** based on your needs

#### Using Package.swift

Add this to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ReachuDevteam/ReachuSwiftSDK.git", from: "1.0.0")
]
```

Then add the products you need to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "ReachuUI", package: "ReachuSwiftSDK"),
        // or other modules: ReachuCore, ReachuLiveShow, ReachuLiveUI
    ]
)
```

### CocoaPods

Add this to your `Podfile`:

```ruby
platform :ios, '15.0'

target 'YourApp' do
  use_frameworks!
  
  # Reachu Swift SDK
  pod 'ReachuSwiftSDK', :git => 'https://github.com/ReachuDevteam/ReachuSwiftSDK.git', :tag => '1.0.0'
end
```

Then run:

```bash
pod install
```

:::tip Stable Release
This is the stable release (`1.0.0`) of Reachu Swift SDK. For beta versions, you can specify `1.0.0-beta.1` explicitly.
:::

### 🎨 Configuration Setup

1. **Copy configuration files** from the demos repo to your project:
   ```bash
   # Copy from: ReachuSwiftSDK-Demos/ReachuDemoApp/ReachuDemoApp/Configuration/
   # To your app bundle as: reachu-config.json
   ```

2. **Choose your theme**:
   - `reachu-config-example.json` - **Dark Streaming Theme** (default)
   - `reachu-config-automatic.json` - **Automatic Light/Dark Theme**
   - `reachu-config-starter.json` - **Minimal configuration**

3. **Load configuration** in your app:

```swift title="App.swift"
import SwiftUI
import ReachuCore
import ReachuUI
import ReachuDesignSystem

@main
struct YourApp: App {
    // MARK: - Global State Managers
    @StateObject private var cartManager = CartManager()
    @StateObject private var checkoutDraft = CheckoutDraft()
    
    init() {
        // Load configuration from reachu-config.json
        // This reads the config file with API key, theme colors, and settings
        ConfigurationLoader.loadConfiguration()
        
        // Or force a specific country (for testing)
        // ConfigurationLoader.loadConfiguration(userCountryCode: "DE")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject managers as environment objects
                .environmentObject(cartManager)
                .environmentObject(checkoutDraft)
                // Show checkout overlay when user taps checkout button
                .sheet(isPresented: $cartManager.isCheckoutPresented) {
                    RCheckoutOverlay()
                        .environmentObject(cartManager)
                        .environmentObject(checkoutDraft)
                }
                // Global floating cart indicator (optional)
                .overlay {
                    RFloatingCartIndicator()
                        .environmentObject(cartManager)
                }
        }
    }
}
```

**What this does:**
- ✅ Loads theme, colors, and settings from `reachu-config.json`
- ✅ Initializes Stripe payments automatically
- ✅ Sets up CartManager for global cart state
- ✅ Configures CheckoutDraft for address normalization
- ✅ Makes managers available to all views via `@EnvironmentObject`

4. **Optional: Set environment variables** in your app for quick theme switching:
   - **In Xcode**: Edit Scheme → Run → Environment Variables
   - **Add**: `REACHU_CONFIG_TYPE` = `dark-streaming` (or `automatic`)
   - **The SDK will automatically use the correct theme**

### Choose Your Modules

Import only what you need:

```swift
// Core functionality only (models, configuration, business logic)
.product(name: "ReachuCore", package: "ReachuSwiftSDK")

// Core + UI Components (ecommerce: cards, sliders, cart, checkout)
.product(name: "ReachuUI", package: "ReachuSwiftSDK")

// Core + LiveShow Logic (livestream data models and manager)
.product(name: "ReachuLiveShow", package: "ReachuSwiftSDK")

// Core + LiveShow + UI Components (full livestream experience)
.product(name: "ReachuLiveUI", package: "ReachuSwiftSDK")

// Everything (complete SDK with all features)
.product(name: "ReachuComplete", package: "ReachuSwiftSDK")
```

## 🎨 UI Components

### RProductCard
Flexible product card with 4 variants:
- **Grid**: Medium cards for main catalogs
- **List**: Compact cards for search results  
- **Hero**: Large cards for featured products
- **Minimal**: Small cards for recommendations

### RProductSlider
Horizontal scrolling component with 6 layouts:
- **Featured**: Hero cards for promotions (280pt)
- **Cards**: Grid cards for categories (180pt)
- **Compact**: Minimal cards for recommendations (120pt)
- **Wide**: Extended cards for detailed view (320pt)
- **Showcase**: Premium cards for special collections (240pt)
- **Micro**: Ultra-compact for space-constrained areas (100pt)

## 🎬 LiveShow Components

### RLiveStreamOverlay
Global livestream system with 3 layout options:
- **Full Screen**: TikTok/Instagram-style immersive experience
- **Bottom Sheet**: Compact overlay with expandable controls
- **Modal**: Traditional video player with organized tabs

### RLiveMiniPlayer
Draggable mini-player for multitasking:
- **Draggable**: Position anywhere on screen
- **Snap to edges**: Automatic edge snapping
- **Expandable**: Tap to return to full experience

### RLiveShowFloatingIndicator
Removable floating indicator for active streams:
- **Auto-show**: Appears when streams are active
- **Dismissable**: User can hide/show manually
- **Configurable position**: 4 corner options

## 🚀 Quick Start

### Ecommerce Components
```swift
import SwiftUI
import ReachuUI

struct ProductView: View {
    let products: [Product]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Featured products slider
                RProductSlider.featured(
                    title: "Featured Products",
                    products: Array(products.prefix(5)),
                    onProductTap: { product in
                        // Handle product tap
                    }
                )
                
                // Product grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ]) {
                    ForEach(products) { product in
                        RProductCard(
                            product: product,
                            variant: .grid,
                            onAddToCart: { 
                                // Handle add to cart
                            }
                        )
                    }
                }
            }
        }
        // Add global cart and checkout overlay
        .overlay {
            RFloatingCartIndicator()
        }
        .sheet(isPresented: $showCheckout) {
            RCheckoutOverlay()
        }
    }
}
```

### LiveShow Integration
```swift
import SwiftUI
import ReachuLiveShow
import ReachuLiveUI

struct MainAppView: View {
    var body: some View {
        YourMainContent()
            // Add global livestream overlay
            .overlay {
                RLiveStreamOverlay()
            }
    }
}

// Show a livestream from anywhere in your app
Button("Join Live Show") {
    LiveShowManager.shared.showLiveStream(stream, layout: .fullScreenOverlay)
}
```

## 📱 Demos

Demos are managed in the `ReachuSwiftSDK-Demos` repository. Each demo consumes the SDK via SPM pinned to a version tag (`vX.Y.Z`).

## 📚 Documentation

- **[Complete Documentation](https://docs.reachu.io/swift-sdk)** - Full documentation site
- **CHANGELOG.md** - Notable changes by version

## 🔧 Development

### Current Status
- ✅ **ReachuCore**: Core models, business logic, and configuration system
- ✅ **ReachuUI**: Complete ecommerce components (Cards, Sliders, Cart, Checkout)
- ✅ **ReachuLiveShow**: Livestream logic and data models
- ✅ **ReachuLiveUI**: Livestream UI components (3 layouts, mini-player, indicators)
- ✅ **ReachuDesignSystem**: Complete design tokens and base components  
- ✅ **Demo App**: Fully functional iOS app with all features
- ✅ **Documentation**: Professional docs integrated with Docusaurus
- ✅ **Dark/Light Mode**: Complete theme system

### Build and Test

```bash
# Build individual modules
swift build --target ReachuCore
swift build --target ReachuUI  
swift build --target ReachuLiveShow
swift build --target ReachuLiveUI

# Build complete SDK
swift build --product ReachuComplete

# SDK testing
# (Demos are built from the ReachuSwiftSDK-Demos repository)
```

### Current Branch

Active development happens on feature branches merged into `main`.


## 🤝 Contributing

This SDK follows a modular, documentation-first approach:

1. **Develop** components in the SDK
2. **Test** in the demo app  
3. **Document** in the docs site
4. **Commit** with semantic messages

## 📄 License

This project is licensed under the MIT License.
