//
//  SupabaseTeamPullService.swift
//  TourOps
//

import Foundation

final class SupabaseTeamPullService: TeamPullServiceProtocol {

    private let apiClient: APIClientProtocol
    private let authService: SyncAuthProviding
    private let baseURL: URL

    init(
        apiClient: APIClientProtocol,
        authService: SyncAuthProviding,
        baseURL: URL
    ) {
        self.apiClient = apiClient
        self.authService = authService
        self.baseURL = baseURL
    }

    func fetchTeams() async throws -> [Team] {
        let accessToken = try await authService.accessToken()

        let dtos: [TeamDTO] = try await SupabasePagedFetcher.fetchAll(
            table: "teams",
            baseURL: baseURL,
            publishableKey: TourOpsSupabaseClient.shared.publishableKey,
            accessToken: accessToken,
            apiClient: apiClient,
            rowType: TeamDTO.self,
            id: \.id
        )

        return dtos.map(TeamMapper.toDomain)
    }
}
