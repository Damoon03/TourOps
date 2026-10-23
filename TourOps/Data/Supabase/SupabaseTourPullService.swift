//
//  SupabaseTourPullService.swift
//  TourOps
//

import Foundation

final class SupabaseTourPullService: TourPullServiceProtocol {

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

    func fetchTours() async throws -> [Tour] {
        let accessToken = try await authService.accessToken()

        let dtos: [TourDTO] = try await SupabasePagedFetcher.fetchAll(
            table: "tours",
            baseURL: baseURL,
            publishableKey: TourOpsSupabaseClient.shared.publishableKey,
            accessToken: accessToken,
            apiClient: apiClient,
            rowType: TourDTO.self
        )

        return dtos.map(TourMapper.toDomain)
    }
}
