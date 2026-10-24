import Foundation
@testable import TourOps

/// An API client written before `sendWithMetadata` existed: it only
/// implements `send`, so it receives the protocol's default metadata, which
/// carries no response headers.
final class SendOnlyAPIClient: APIClientProtocol {

    private let responseData: Data

    private(set) var sendCallCount = 0

    init(responseData: Data) {
        self.responseData = responseData
    }

    func send<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        sendCallCount += 1

        return try JSONDecoder().decode(
            Response.self,
            from: responseData
        )
    }
}
