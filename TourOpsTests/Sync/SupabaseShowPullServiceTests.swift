//
//  SupabaseShowPullServiceTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 7/14/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

struct SupabaseShowPullServiceTests {

    @Test
    func fetchShowsReturnsMappedShows() async throws {

        let showID = UUID()
        let tourID = UUID()
        let date = Date(timeIntervalSince1970: 100)
        let createdAt = Date(timeIntervalSince1970: 200)

        let apiClient = ShowMockAPIClient(
            response: [
                ShowDTO(
                    id: showID,
                    tourID: tourID,
                    name: "Paris Show",
                    venue: "Olympia",
                    city: "Paris",
                    date: date,
                    createdAt: createdAt,
                    version: 3
                )
            ]
        )

        let authService = ShowMockAuthService()

        let baseURL = URL(
            string: "https://example.supabase.co"
        )!

        let service = SupabaseShowPullService(
            apiClient: apiClient,
            authService: authService,
            baseURL: baseURL
        )

        let shows = try await service.fetchShows()

        #expect(shows.count == 1)
        #expect(shows[0].id == showID)
        #expect(shows[0].tourID == tourID)
        #expect(shows[0].name == "Paris Show")
        #expect(shows[0].venue == "Olympia")
        #expect(shows[0].city == "Paris")
        #expect(shows[0].date == date)
        #expect(shows[0].createdAt == createdAt)
        #expect(shows[0].version == 3)

        #expect(apiClient.sendCallCount == 1)
        #expect(authService.accessTokenCallCount == 1)
    }

    @Test
    func fetchShowsBuildsAuthenticatedGETRequest() async throws {

        let apiClient = ShowMockAPIClient(
            response: []
        )

        let authService = ShowMockAuthService()

        let baseURL = URL(
            string: "https://example.supabase.co"
        )!

        let service = SupabaseShowPullService(
            apiClient: apiClient,
            authService: authService,
            baseURL: baseURL
        )

        _ = try await service.fetchShows()

        #expect(apiClient.lastRequest?.httpMethod == "GET")

        #expect(
            apiClient.lastRequest?.url?.absoluteString
            == "https://example.supabase.co/rest/v1/shows"
        )

        #expect(
            apiClient.lastRequest?.value(
                forHTTPHeaderField: "Authorization"
            )
            == "Bearer test-access-token"
        )
    }
}

private final class ShowMockAPIClient: APIClientProtocol {

    private let response: [ShowDTO]

    private(set) var sendCallCount = 0
    private(set) var lastRequest: URLRequest?

    init(response: [ShowDTO]) {
        self.response = response
    }

    func send<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {

        sendCallCount += 1
        lastRequest = request

        return response as! Response
    }
}

private final class ShowMockAuthService: SyncAuthProviding {

    private(set) var accessTokenCallCount = 0

    func accessToken() async throws -> String {

        accessTokenCallCount += 1

        return "test-access-token"
    }

    func userID() async throws -> UUID {
        UUID()
    }
}
