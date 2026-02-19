import Foundation

/// Protocol for network client abstraction
/// Allows dependency injection for testing and better architecture
protocol NetworkClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Default implementation using URLSession
extension URLSession: NetworkClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        return try await self.data(for: request)
    }
}
