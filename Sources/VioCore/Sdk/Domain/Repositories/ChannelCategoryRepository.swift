import Foundation

public protocol ChannelCategoryRepository {
    func get() async throws -> [GetCategoryDto]
}
