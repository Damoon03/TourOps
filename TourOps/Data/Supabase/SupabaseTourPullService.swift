//
//  SupabaseTourPullService.swift
//  TourOps
//
//  Created by Damoon saber on 7/13/1405 AP.
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
        guard let url = URL(
            string: "/rest/v1/tours",
            relativeTo: baseURL
        ) else {
            throw APIClientError.invalidResponse
        }

        var request = URLRequest(url: url)

        request.httpMethod = HTTPMethod.GET.rawValue

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        request.setValue(
            TourOpsSupabaseClient.shared.publishableKey,
            forHTTPHeaderField: "apikey"
        )

        let accessToken = try await authService.accessToken()

        request.setValue(
            "Bearer \(accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        let dtos: [TourDTO] = try await apiClient.send(
            request,
            responseType: [TourDTO].self
        )

        return dtos.map(TourMapper.toDomain)
    }
}
