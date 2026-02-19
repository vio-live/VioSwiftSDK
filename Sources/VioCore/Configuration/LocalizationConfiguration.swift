import Foundation

/// Localization configuration for SDK strings
public struct LocalizationConfiguration {
    /// Default language code (e.g., "en", "es", "no", "sv")
    public let defaultLanguage: String
    
    /// Supported languages and their translations
    public let translations: [String: [String: String]]
    
    /// Fallback language if translation is missing
    public let fallbackLanguage: String
    
    public init(
        defaultLanguage: String = "en",
        translations: [String: [String: String]] = [:],
        fallbackLanguage: String = "en"
    ) {
        self.defaultLanguage = defaultLanguage
        self.translations = translations
        self.fallbackLanguage = fallbackLanguage
    }
    
    /// Default configuration with English translations built-in
    public static let `default` = LocalizationConfiguration(
        defaultLanguage: "en",
        translations: ["en": VioTranslationKey.defaultEnglish],
        fallbackLanguage: "en"
    )
    
    /// Get translation for a key in a specific language
    public func translation(for key: String, language: String? = nil) -> String? {
        let lang = language ?? defaultLanguage
        
        // Try requested language
        if let translations = translations[lang],
           let translation = translations[key] {
            return translation
        }
        
        // Fallback to default language
        if lang != defaultLanguage,
           let translations = translations[defaultLanguage],
           let translation = translations[key] {
            return translation
        }
        
        // Fallback to fallback language
        if defaultLanguage != fallbackLanguage,
           let translations = translations[fallbackLanguage],
           let translation = translations[key] {
            return translation
        }
        
        // Final fallback: use built-in English translations if available
        if let englishTranslation = VioTranslationKey.defaultEnglish[key] {
            return englishTranslation
        }
        
        return nil
    }
}

