//
//  APIClientTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 9/9/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

struct APIClientTests {

    @Test
    func sendDecodesSuccessfulResponse() async throws {
        let session = makeMockSession()

        let client = APIClient(
            session: session
        )

        let request = URLRequest(
            url: URL(
                string: "https://example.com/teams?status=200"
            )!
        )

        let response = try await client.send(
            request,
            responseType: TestResponse.self
        )

        #expect(response.name == "Northbound")
    }

    @Test
    func sendThrowsForNonSuccessfulResponse() async {
        let session = makeMockSession()

        let client = APIClient(
            session: session
        )

        let request = URLRequest(
            url: URL(
                string: "https://example.com/teams?status=500"
            )!
        )

        do {
            _ = try await client.send(
                request,
                responseType: TestResponse.self
            )

            Issue.record(
                "Expected APIClientError.httpError"
            )
        } catch let error as APIClientError {
            switch error {
            case .httpError(let statusCode):
                #expect(statusCode == 500)

            default:
                Issue.record(
                    "Expected httpError, got \(error)"
                )
            }
        } catch {
            Issue.record(
                "Expected APIClientError, got \(error)"
            )
        }
    }
}

private struct TestResponse: Decodable {
    let name: String
}

private func makeMockSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral

    configuration.protocolClasses = [
        MockURLProtocol.self
    ]

    return URLSession(
        configuration: configuration
    )
}

private final class MockURLProtocol: URLProtocol {

    override class func canInit(
        with request: URLRequest
    ) -> Bool {
        true
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badURL)
            )
            return
        }

        let statusCode =
            URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )?
            .queryItems?
            .first(where: {
                $0.name == "status"
            })?
            .value
            .flatMap(Int.init) ?? 200

        let data: Data

        if statusCode == 200 {
            let json = """
            {
                "name": "Northbound"
            }
            """

            data = Data(json.utf8)
        } else {
            data = Data()
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!

        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )

        client?.urlProtocol(
            self,
            didLoad: data
        )

        client?.urlProtocolDidFinishLoading(
            self
        )
    }

    override func stopLoading() {}
}
