// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VioSwiftSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        // Core product - always needed (FASE 1)
        .library(
            name: "VioCore",
            targets: ["VioCore"]
        ),

        // Network module - internal shared networking (FASE 1)
        .library(
            name: "VioNetwork",
            targets: ["VioNetwork"]
        ),

        // UI Components - optional target (FASE 2)
        .library(
            name: "VioUI",
            targets: ["VioCore", "VioUI"]
        ),

        // Design System - internal UI shared components (FASE 2)
        .library(
            name: "VioDesignSystem",
            targets: ["VioDesignSystem"]
        ),

        // Engagement System - engagement logic and models (FASE 4)
        .library(
            name: "VioEngagementSystem",
            targets: ["VioEngagementSystem"]
        ),

        // Engagement UI - engagement UI components (FASE 4)
        .library(
            name: "VioEngagementUI",
            targets: ["VioEngagementSystem", "VioEngagementUI"]
        ),

        // LiveShow - optional target (FASE 3)
        // .library(
        //     name: "VioLiveShow",
        //     targets: ["VioCore", "VioLiveShow"]
        // ),

        // Testing utilities - internal testing helpers
        .library(
            name: "VioTesting",
            targets: ["VioTesting"]
        ),

        // LiveShow UI Components - optional target (FASE 3)
        // .library(
        //     name: "VioLiveUI",
        //     targets: ["VioCore", "VioLiveShow", "VioLiveUI"]
        // ),

        // Complete SDK - everything included
        // .library(
        //     name: "VioComplete",
        //     targets: [
        //         "VioCore", "VioDesignSystem", "VioUI", "VioLiveShow", "VioLiveUI",
        //     ]
        // ),
        // Casting UI - live match casting components
        .library(
            name: "VioCastingUI",
            targets: ["VioCastingUI"]
        ),

        .library(
            name: "VioComplete",
            targets: [
                "VioCore",
                "VioNetwork",
                "VioDesignSystem",
                "VioUI",
                "VioEngagementSystem",
                "VioEngagementUI",
                "VioCastingUI"
            ]
        ),        
    ],
    dependencies: [
        // GraphQL client for Vio API
        .package(url: "https://github.com/apollographql/apollo-ios.git", from: "1.0.0"),

        // WebSocket for LiveShow real-time features
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0"),

        // Image caching for UI components
        .package(url: "https://github.com/kean/Nuke.git", from: "12.0.0"),

        .package(url: "https://github.com/stripe/stripe-ios", .upToNextMajor(from: "24.24.1")),

        .package(
            url: "https://github.com/klarna/klarna-mobile-sdk-spm.git",
            exact: "2.8.0"
        ),
        // Socket.IO client for Tipio realtime backend
        .package(url: "https://github.com/socketio/socket.io-client-swift", from: "16.0.0"),
        
        // Mixpanel for analytics tracking
        .package(url: "https://github.com/mixpanel/mixpanel-swift", from: "4.0.0"),

    ],
    targets: [
        // MARK: - INTERNAL: Network Target (Shared)
        .target(
            name: "VioNetwork",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios")
            ],
            path: "Sources/VioNetwork"
        ),

        // MARK: - FASE 1: Core Target (Required)
        .target(
            name: "VioCore",
            dependencies: [
                "VioNetwork",
                .product(name: "Mixpanel", package: "mixpanel-swift")
            ],
            path: "Sources/VioCore",
            exclude: [
                // Documentation and examples (not part of the target build)
                "Configuration/LOCALIZATION_GUIDE.md",
                "Configuration/MARKET_AVAILABILITY_GUIDE.md",
                "Configuration/CAMPAIGN_LIFECYCLE_GUIDE.md",
                "Configuration/ThemeConfigurationSystem.md",
                "Sdk/README.md",
                // Theme example JSONs and readme
                "Configuration/theme-examples/README.md",
                "Configuration/theme-examples/automatic-theme.json",
                "Configuration/theme-examples/vio-translations.json",
                "Configuration/theme-examples/green-ecommerce-theme.json",
                "Configuration/theme-examples/dark-only-theme.json",
                "Configuration/theme-examples/minimal-theme.json",
                "Configuration/theme-examples/professional-blue-theme.json",
                "Configuration/theme-examples/vio-config-with-localization.json",
            ]
        ),

        // MARK: - INTERNAL: Design System Target (Shared)
        .target(
            name: "VioDesignSystem",
            dependencies: [
                "VioCore",
                .product(name: "Nuke", package: "Nuke"),
            ],
            path: "Sources/VioDesignSystem"
        ),

        // MARK: - FASE 2: UI Components Target (Optional)
        .target(
            name: "VioUI",
            dependencies: [
                "VioCore",
                "VioDesignSystem",
                "VioTesting",  // For previews and mock data
                .product(
                    name: "StripePaymentSheet", package: "stripe-ios",
                    condition: .when(platforms: [.iOS])),
                .product(
                    name: "KlarnaMobileSDK", package: "klarna-mobile-sdk-spm",
                    condition: .when(platforms: [.iOS])),

            ],
            path: "Sources/VioUI",
            exclude: [
                "Components/VProductSlider/README.md",
                "Components/README.md",
                "Components/VOfferBanner.md",
            ],
            resources: [
                .process("Resources")
            ]
        ),

        // MARK: - FASE 3: LiveShow Target (Optional)
        .target(
            name: "VioLiveShow",
            dependencies: [
                "VioCore",
                "VioNetwork",
                .product(name: "Starscream", package: "Starscream"),
                .product(name: "SocketIO", package: "socket.io-client-swift"),
            ],
            path: "Sources/VioLiveShow"
        ),

        // MARK: - FASE 3: LiveShow UI Target (Optional)
        .target(
            name: "VioLiveUI",
            dependencies: [
                "VioCore",
                "VioLiveShow",
                "VioUI",
                "VioDesignSystem",
            ],
            path: "Sources/VioLiveUI"
        ),

        // MARK: - FASE 4: Engagement System Target (Optional)
        .target(
            name: "VioEngagementSystem",
            dependencies: [
                "VioCore",
            ],
            path: "Sources/VioEngagementSystem"
        ),

        // MARK: - FASE 4: Engagement UI Target (Optional)
        .target(
            name: "VioEngagementUI",
            dependencies: [
                "VioCore",
                "VioEngagementSystem",
                "VioDesignSystem",
            ],
            path: "Sources/VioEngagementUI"
        ),

        // MARK: - INTERNAL: Testing Utilities Target
        .target(
            name: "VioTesting",
            dependencies: [
                "VioCore",
                "VioNetwork",
            ],
            path: "Sources/VioTesting"
        ),

        // MARK: - Casting UI Target
        .target(
            name: "VioCastingUI",
            dependencies: [
                "VioCore",
                "VioUI",
                "VioEngagementSystem",
                "VioEngagementUI",
                "VioDesignSystem",
            ],
            path: "Sources/VioCastingUI"
        ),

        // MARK: - Test Targets
        .testTarget(
            name: "VioCoreTests",
            dependencies: [
                "VioCore",
            ],
            path: "Tests/VioCoreTests"
        ),
        // VioUITests requires iOS simulator (UIKit) — re-enable when running on iOS
        // .testTarget(
        //     name: "VioUITests",
        //     dependencies: ["VioUI", "VioCore", "VioDesignSystem", "VioLiveShow"],
        //     path: "Tests/VioUITests"
        // )
    ]
)
