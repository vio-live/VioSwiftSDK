import Foundation

public protocol ChannelInfoRepository {
    func getChannels() async throws -> [GetChannelsDto]
    func getPurchaseConditions() async throws -> GetTermsAndConditionsDto
    func getTermsAndConditions() async throws -> GetTermsAndConditionsDto
}
