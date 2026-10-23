//
//  APIClient.swift
//  TourOps
//
//  Created by Damoon saber on 9/9/1405 AP.
//

import Foundation

final class APIClient: APIClientProtocol {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        let response: APIClientResponse<Response> = try await sendWithMetadata(
            request,
            responseType: responseType
        )
        return response.body
    }

    func sendWithMetadata<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> APIClientResponse<Response> {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIClientError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIClientError.httpError(
                statusCode: httpResponse.statusCode
            )
        }

        do {
            let body = try JSONCoding.decoder.decode(
                Response.self,
                from: data
            )

            var headers: [String: String] = [:]
            for (key, value) in httpResponse.allHeaderFields {
                if let key = key as? String {
                    headers[key] = String(describing: value)
                }
            }

            return APIClientResponse(
                body: body,
                statusCode: httpResponse.statusCode,
                headers: headers
            )
        } catch {
            throw APIClientError.decodingError(error)
        }
    }
}
