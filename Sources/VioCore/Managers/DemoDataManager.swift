//
//  DemoDataManager.swift
//  VioCore
//
//  Manager for accessing demo static data configuration
//  Provides easy access to demo data throughout the SDK
//

import Foundation
import SwiftUI

/// Manager for accessing demo static data configuration
/// Provides easy access to demo data throughout the SDK
public class DemoDataManager {
    
    // MARK: - Singleton
    
    public static let shared = DemoDataManager()
    
    // MARK: - Properties
    
    private var configuration: DemoDataConfiguration {
        VioConfiguration.shared.demoDataConfiguration
    }
    
    private init() {}
    
    // MARK: - Asset Access
    
    /// Get default logo asset name
    public var defaultLogo: String {
        configuration.assets.defaultLogo
    }
    
    /// Get default avatar asset name (brand avatar - consistent with effectiveBrandConfiguration)
    public var defaultAvatar: String {
        VioConfiguration.shared.effectiveBrandConfiguration.iconAsset
    }
    
    /// Get background image asset name
    public func backgroundImage(for type: BackgroundImageType) -> String {
        switch type {
        case .footballField:
            return configuration.assets.backgroundImages.footballField
        case .mainBackground:
            return configuration.assets.backgroundImages.mainBackground
        case .sportDetail:
            return configuration.assets.backgroundImages.sportDetail
        case .sportDetailImage:
            return configuration.assets.backgroundImages.sportDetailImage
        }
    }
    
    /// Get brand asset name
    public func brandAsset(for type: BrandAssetType) -> String {
        switch type {
        case .icon:
            return configuration.assets.brandAssets.icon
        case .logo:
            return configuration.assets.brandAssets.logo
        }
    }
    
    /// Get contest asset name
    public func contestAsset(for type: ContestAssetType) -> String {
        switch type {
        case .giftCard:
            return configuration.assets.contestAssets.giftCard
        case .championsLeagueTickets:
            return configuration.assets.contestAssets.championsLeagueTickets
        }
    }
    
    // MARK: - Demo Users
    
    /// Get default username for demo
    public var defaultUsername: String {
        configuration.demoUsers.defaultUsername
    }
    
    /// Get random chat username for demo
    public func randomChatUsername() -> DemoDataConfiguration.DemoUserConfiguration.ChatUsername? {
        configuration.demoUsers.chatUsernames.randomElement()
    }
    
    /// Get chat username at index (for timeline events)
    public func chatUsername(at index: Int) -> DemoDataConfiguration.DemoUserConfiguration.ChatUsername? {
        let usernames = configuration.demoUsers.chatUsernames
        guard index >= 0, index < usernames.count else { return nil }
        return usernames[index]
    }
    
    /// Get social account by name
    public func socialAccount(named name: String) -> DemoDataConfiguration.DemoUserConfiguration.SocialAccount? {
        configuration.demoUsers.socialAccounts.first { $0.name == name }
    }
    
    /// Get social account at index (for timeline events)
    public func socialAccount(at index: Int) -> DemoDataConfiguration.DemoUserConfiguration.SocialAccount? {
        let accounts = configuration.demoUsers.socialAccounts
        guard index >= 0, index < accounts.count else { return nil }
        return accounts[index]
    }
    
    // MARK: - Timeline Events
    
    /// Get casting contests from config (for demo timeline)
    public var timelineCastingContests: [DemoDataConfiguration.TimelineEventsConfiguration.CastingContestItem] {
        configuration.timelineEvents.castingContests
    }
    
    /// Get casting products from config (for demo timeline)
    public var timelineCastingProducts: [DemoDataConfiguration.TimelineEventsConfiguration.CastingProductItem] {
        configuration.timelineEvents.castingProducts
    }
    
    // MARK: - Product Mappings
    
    /// Get product URL for product ID
    public func productUrl(for productId: String) -> String? {
        configuration.productMappings[productId]?.productUrl
    }
    
    /// Get checkout URL for product ID
    public func checkoutUrl(for productId: String) -> String? {
        configuration.productMappings[productId]?.checkoutUrl
    }
    
    /// Get product mapping for product ID
    public func productMapping(for productId: String) -> DemoDataConfiguration.ProductMapping? {
        configuration.productMappings[productId]
    }
    
    // MARK: - Event IDs
    
    /// Get event ID for contest quiz
    public var contestQuizEventId: String {
        configuration.eventIds.contestQuiz
    }
    
    /// Get event ID for contest giveaway
    public var contestGiveawayEventId: String {
        configuration.eventIds.contestGiveaway
    }
    
    /// Get event ID for product combo
    public var productComboEventId: String {
        configuration.eventIds.productCombo
    }
    
    /// Get event ID for tweet halftime 1
    public var tweetHalftime1EventId: String {
        configuration.eventIds.tweetHalftime1
    }
    
    /// Get event ID for tweet halftime 2
    public var tweetHalftime2EventId: String {
        configuration.eventIds.tweetHalftime2
    }
    
    // MARK: - Match Defaults
    
    /// Get broadcast ID for match key
    public func broadcastId(for matchKey: String) -> String? {
        configuration.matchDefaults.broadcastIdMappings[matchKey]
    }
    
    /// Get default score
    public var defaultScore: Int {
        configuration.matchDefaults.defaultScore
    }
    
    // MARK: - Offer Banner
    
    /// Get offer banner countdown
    public var offerBannerCountdown: DemoDataConfiguration.OfferBannerConfiguration.CountdownConfiguration {
        configuration.offerBanner.countdown
    }
    
    /// Get offer banner title
    public var offerBannerTitle: String {
        configuration.offerBanner.title
    }
    
    /// Get offer banner subtitle
    public var offerBannerSubtitle: String {
        configuration.offerBanner.subtitle
    }
    
    /// Get offer banner discount text
    public var offerBannerDiscountText: String {
        configuration.offerBanner.discountText
    }
    
    /// Get offer banner button text
    public var offerBannerButtonText: String {
        configuration.offerBanner.buttonText
    }
    
    // MARK: - Sport View Data
    
    /// Get carousel cards for SportView "Vår beste sport" section
    public var carouselCards: [DemoDataConfiguration.CarouselCardItem] {
        configuration.carouselCards
    }
    
    /// Get live cards for SportView "Live akkurat nå" section
    public var liveCards: [DemoDataConfiguration.LiveCardItem] {
        configuration.liveCards
    }
    
    /// Get sport clips for SportView "De beste klippene akkurat nå" section
    public var sportClips: [DemoDataConfiguration.SportClipItem] {
        configuration.sportClips
    }
}

// MARK: - Supporting Enums

public enum BackgroundImageType {
    case footballField
    case mainBackground
    case sportDetail
    case sportDetailImage
}

public enum BrandAssetType {
    case icon
    case logo
}

public enum ContestAssetType {
    case giftCard
    case championsLeagueTickets
}
