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
        let json = """
        {
            "name": "Northbound"
        }
        """

        let session = makeMockSession(
            data: Data(json.utf8),
            statusCode: 200
        )

        let client = APIClient(session: session)

        let request = URLRequest(
            url: URL(string: "https://example.com/teams")!
        )

        let response = try await client.send(
            request,
            responseType: TestResponse.self
        )

        #expect(response.name == "Northbound")
    }

    @Test
    func sendThrowsForNonSuccessfulResponse() async {
        let session = makeMockSession(
            data: Data(),
            statusCode: 500
        )

        let client = APIClient(session: session)

        let request = URLRequest(
            url: URL(string: "https://example.com/teams")!
        )

        await #expect(throws: URLError.self) {
            try await client.send(
                request,
                responseType: TestResponse.self
            )
        }
    }
}

// MARK: - Test Support

private struct TestResponse: Decodable {
    let name: String
}

private func makeMockSession(
    data: Data,
    statusCode: Int
) -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral

    configuration.protocolClasses = [
        MockURLProtocol.self
    ]

    MockURLProtocol.responseData = data
    MockURLProtocol.statusCode = statusCode

    return URLSession(configuration: configuration)
}

private final class MockURLProtocol: URLProtocol {

    static var responseData = Data()
    static var statusCode = 200

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

        let response = HTTPURLResponse(
            url: url,
            statusCode: Self.statusCode,
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
            didLoad: Self.responseData
        )

        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
