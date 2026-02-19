import Foundation

public protocol MarketRepository {
    func getAvailable() async throws -> [GetAvailableGlobalMarketsDto]
}
