import Foundation

protocol APIClientProtocol {
    func send<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response

    func sendWithMetadata<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> APIClientResponse<Response>
}

struct APIClientResponse<Body> {
    let body: Body
    let statusCode: Int
    private let headers: [String: String]

    init(
        body: Body,
        statusCode: Int,
        headers: [String: String]
    ) {
        self.body = body
        self.statusCode = statusCode
        self.headers = headers
    }

    func value(forHTTPHeaderField name: String) -> String? {
        headers.first {
            $0.key.caseInsensitiveCompare(name) == .orderedSame
        }?.value
    }
}

extension APIClientProtocol {
    // Compatibility for existing clients. Pulls fail closed if real metadata is unavailable.
    func sendWithMetadata<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> APIClientResponse<Response> {
        let body = try await send(
            request,
            responseType: responseType
        )

        return APIClientResponse(
            body: body,
            statusCode: 200,
            headers: [:]
        )
    }
}
