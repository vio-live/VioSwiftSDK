import Foundation

public protocol ChannelMarketRepository {
    func getAvailable() async throws -> [GetAvailableMarketsDto]
}
