//
//  DefaultSyncService.swift
//  TourOps
//

import Foundation

final class DefaultSyncService: SyncServiceProtocol {

    private let apiClient: APIClientProtocol
    private let requestBuilder: SyncRequestBuilderProtocol

    init(
        apiClient: APIClientProtocol,
        requestBuilder: SyncRequestBuilderProtocol
    ) {
        self.apiClient = apiClient
        self.requestBuilder = requestBuilder
    }


    func execute(
        _ operation: SyncOperation
    ) async throws {

        let request = try requestBuilder.build(
            from: operation
        )

        let _: EmptyResponse = try await apiClient.send(
            request,
            responseType: EmptyResponse.self
        )
    }
}


private struct EmptyResponse: Decodable {}
