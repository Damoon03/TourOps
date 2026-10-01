//
//  SupabaseTeamPullServiceTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 7/9/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

struct SupabaseTeamPullServiceTests {

    @Test
    func fetchTeamsReturnsMappedTeams() async throws {

        let teamID = UUID()
        let createdAt = Date(timeIntervalSince1970: 100)

        let apiClient = MockAPIClient(
            response: [
                TeamDTO(
                    id: teamID,
                    name: "Northbound",
                    genre: "Rock",
                    country: "Iran",
                    city: "Rasht",
                    createdAt: createdAt,
                    version: 3
                )
            ]
        )

        let authService = MockAuthService()

        let baseURL = URL(
            string: "https://example.supabase.co"
        )!

        let service = SupabaseTeamPullService(
            apiClient: apiClient,
            authService: authService,
            baseURL: baseURL
        )

        let teams = try await service.fetchTeams()

        #expect(teams.count == 1)
        #expect(teams[0].id == teamID)
        #expect(teams[0].name == "Northbound")
        #expect(teams[0].genre == "Rock")
        #expect(teams[0].country == "Iran")
        #expect(teams[0].city == "Rasht")
        #expect(teams[0].createdAt == createdAt)
        #expect(teams[0].version == 3)

        #expect(apiClient.sendCallCount == 1)
        #expect(authService.accessTokenCallCount == 1)
    }

    @Test
    func fetchTeamsBuildsAuthenticatedGETRequest() async throws {

        let apiClient = MockAPIClient(
            response: []
        )

        let authService = MockAuthService()

        let baseURL = URL(
            string: "https://example.supabase.co"
        )!

        let service = SupabaseTeamPullService(
            apiClient: apiClient,
            authService: authService,
            baseURL: baseURL
        )

        _ = try await service.fetchTeams()

        #expect(apiClient.lastRequest?.httpMethod == "GET")

        #expect(
            apiClient.lastRequest?.url?.absoluteString
            == "https://example.supabase.co/rest/v1/teams"
        )

        #expect(
            apiClient.lastRequest?.value(
                forHTTPHeaderField: "Authorization"
            )
            == "Bearer test-access-token"
        )
    }
}

private final class MockAPIClient: APIClientProtocol {

    private let response: [TeamDTO]

    private(set) var sendCallCount = 0
    private(set) var lastRequest: URLRequest?

    init(response: [TeamDTO]) {
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

private final class MockAuthService: SyncAuthProviding {

    private(set) var accessTokenCallCount = 0

    func accessToken() async throws -> String {

        accessTokenCallCount += 1

        return "test-access-token"
    }

    func userID() async throws -> UUID {
        UUID()
    }
}
