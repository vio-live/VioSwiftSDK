import Foundation

/// Central localization system for Vio SDK
/// Provides localized strings for all SDK components
public class VioLocalization {
    
    // MARK: - Singleton
    public static let shared = VioLocalization()
    
    // MARK: - Properties
    private var configuration: LocalizationConfiguration = .default
    private var currentLanguage: String = "en"
    
    private init() {}
    
    // MARK: - Configuration
    
    /// Update localization configuration
    public func configure(_ config: LocalizationConfiguration) {
        self.configuration = config
        self.currentLanguage = config.defaultLanguage
    }
    
    /// Set current language
    public func setLanguage(_ language: String) {
        self.currentLanguage = language
    }
    
    /// Get current language
    public var language: String {
        return currentLanguage
    }
    
    // MARK: - Translation Methods
    
    /// Get localized string for a key
    /// - Parameters:
    ///   - key: Translation key
    ///   - language: Optional language override (uses current language if nil)
    ///   - defaultValue: Default value if translation not found
    /// - Returns: Localized string
    public func string(
        for key: String,
        language: String? = nil,
        defaultValue: String? = nil
    ) -> String {
        // Try to get translation
        if let translation = configuration.translation(
            for: key,
            language: language ?? currentLanguage
        ) {
            return translation
        }
        
        // Try default English values
        if let defaultValue = VioTranslationKey.defaultEnglish[key] {
            return defaultValue
        }
        
        // Return provided default value or key itself
        return defaultValue ?? key
    }
    
    /// Get localized string with format arguments
    public func string(
        for key: String,
        arguments: CVarArg...,
        language: String? = nil,
        defaultValue: String? = nil
    ) -> String {
        let format = string(for: key, language: language, defaultValue: defaultValue)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - Convenience Extensions

/// Convenience function to get localized string
public func RLocalizedString(_ key: String, defaultValue: String? = nil) -> String {
    return VioLocalization.shared.string(for: key, defaultValue: defaultValue)
}

/// Convenience function to get localized string with arguments
public func RLocalizedString(_ key: String, _ arguments: CVarArg..., defaultValue: String? = nil) -> String {
    return VioLocalization.shared.string(for: key, arguments: arguments, defaultValue: defaultValue)
}

