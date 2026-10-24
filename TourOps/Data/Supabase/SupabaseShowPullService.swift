//
//  SupabaseShowPullService.swift
//  TourOps
//

import Foundation

final class SupabaseShowPullService: ShowPullServiceProtocol {

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

    func fetchShows() async throws -> [Show] {
        let accessToken = try await authService.accessToken()

        let dtos: [ShowDTO] = try await SupabasePagedFetcher.fetchAll(
            table: "shows",
            baseURL: baseURL,
            publishableKey: TourOpsSupabaseClient.shared.publishableKey,
            accessToken: accessToken,
            apiClient: apiClient,
            rowType: ShowDTO.self,
            id: \.id
        )

        return dtos.map(ShowMapper.toDomain)
    }
}
