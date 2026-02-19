import Foundation

/// Centralized logging system for Vio SDK
/// Respects `enableLogging` and `logLevel` from NetworkConfiguration
public struct VioLogger {
    
    /// Log levels ordered by severity
    public enum Level: Int, Comparable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Check if logging is enabled
    private static var isEnabled: Bool {
        VioConfiguration.shared.networkConfiguration.enableLogging
    }
    
    /// Get minimum log level from configuration
    private static var minLevel: Level {
        let configLevel = VioConfiguration.shared.networkConfiguration.logLevel
        switch configLevel {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }
    
    /// Log a message if logging is enabled and level is sufficient
    private static func log(_ level: Level, _ message: String, component: String? = nil) {
        guard isEnabled else { return }
        guard level >= minLevel else { return }
        
        let prefix = component != nil ? "[\(component!)]" : "[Vio]"
        let emoji: String
        switch level {
        case .debug: emoji = "🔍"
        case .info: emoji = "ℹ️"
        case .warning: emoji = "⚠️"
        case .error: emoji = "❌"
        }
        
        print("\(emoji) \(prefix) \(message)")
    }
    
    // MARK: - Public API
    
    /// Log a debug message
    public static func debug(_ message: String, component: String? = nil) {
        log(.debug, message, component: component)
    }
    
    /// Log an info message
    public static func info(_ message: String, component: String? = nil) {
        log(.info, message, component: component)
    }
    
    /// Log a warning message
    public static func warning(_ message: String, component: String? = nil) {
        log(.warning, message, component: component)
    }
    
    /// Log an error message
    public static func error(_ message: String, component: String? = nil) {
        log(.error, message, component: component)
    }
    
    /// Log success (always shown if logging enabled, regardless of level)
    public static func success(_ message: String, component: String? = nil) {
        guard isEnabled else { return }
        let prefix = component != nil ? "[\(component!)]" : "[Vio]"
        print("✅ \(prefix) \(message)")
    }
}

