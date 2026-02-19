/// Vio Testing Utilities
/// 
/// Provides testing utilities for the Vio SDK

import Foundation

/// Main entry point for Vio Testing utilities
public struct VioTesting {
    
    /// Initialize testing utilities
    public static func configure() {
        print("🧪 Vio Testing utilities initialized")
    }
}

// MARK: - Public Exports

// Export MockDataProvider for use in other modules
public typealias VioMockDataProvider = MockDataProvider
