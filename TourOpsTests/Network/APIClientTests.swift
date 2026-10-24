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
    func sendWithMetadataPreservesResponseHeaders() async throws {
        let client = APIClient(session: makeMockSession())
        let request = URLRequest(
            url: URL(
                string: "https://example.com/teams?status=200&contentRange=0-0/1"
            )!
        )

        let response = try await client.sendWithMetadata(
            request,
            responseType: TestResponse.self
        )

        #expect(response.body.name == "Northbound")
        #expect(response.statusCode == 200)
        #expect(response.value(forHTTPHeaderField: "Content-Range") == "0-0/1")
    }

    @Test
    func sendWithMetadataReportsNoHeaderWhenServerSendsNone() async throws {
        let client = APIClient(session: makeMockSession())
        let request = URLRequest(
            url: URL(string: "https://example.com/teams?status=200")!
        )

        let response = try await client.sendWithMetadata(
            request,
            responseType: TestResponse.self
        )

        #expect(response.value(forHTTPHeaderField: "Content-Range") == nil)
    }

    @Test
    func sendWithMetadataFindsHeaderRegardlessOfCase() async throws {
        let client = APIClient(session: makeMockSession())
        let request = URLRequest(
            url: URL(
                string: "https://example.com/teams?status=200&lowercaseContentRange=0-0/1"
            )!
        )

        let response = try await client.sendWithMetadata(
            request,
            responseType: TestResponse.self
        )

        #expect(response.value(forHTTPHeaderField: "Content-Range") == "0-0/1")
        #expect(response.value(forHTTPHeaderField: "CONTENT-RANGE") == "0-0/1")
    }

    @Test
    func sendWithMetadataThrowsForNonSuccessfulResponse() async {
        let client = APIClient(session: makeMockSession())
        let request = URLRequest(
            url: URL(string: "https://example.com/teams?status=500")!
        )

        do {
            _ = try await client.sendWithMetadata(
                request,
                responseType: TestResponse.self
            )

            Issue.record("Expected APIClientError.httpError")
        } catch APIClientError.httpError(let statusCode) {
            #expect(statusCode == 500)
        } catch {
            Issue.record("Expected APIClientError.httpError, got \(error)")
        }
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
    
    @Test
    func sendThrowsNetworkErrorWhenRequestFails() async {
        let session = makeMockSession()

        let client = APIClient(
            session: session
        )

        let request = URLRequest(
            url: URL(
                string: "https://example.com/teams?error=network"
            )!
        )

        do {
            _ = try await client.send(
                request,
                responseType: TestResponse.self
            )

            Issue.record(
                "Expected APIClientError.networkError"
            )
        } catch let error as APIClientError {
            switch error {
            case .networkError(let urlError):
                #expect(
                    urlError.code == .notConnectedToInternet
                )

            default:
                Issue.record(
                    "Expected networkError, got \(error)"
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
        
        if url.query == "error=network" {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.notConnectedToInternet)
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

        // Only the headers a test asks for are attached, like a real server
        // that does not always send pagination metadata.
        let queryItems = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.queryItems ?? []

        var headerFields: [String: String] = [:]

        if let contentRange = queryItems.first(
            where: { $0.name == "contentRange" }
        )?.value {
            headerFields["Content-Range"] = contentRange
        }

        if let contentRange = queryItems.first(
            where: { $0.name == "lowercaseContentRange" }
        )?.value {
            headerFields["content-range"] = contentRange
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headerFields
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
