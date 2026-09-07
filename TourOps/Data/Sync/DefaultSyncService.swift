//
//  DefaultSyncService.swift
//  TourOps
//
//  Created by Damoon saber on 9/8/1405 AP.
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

        do {
            let _: EmptyResponse = try await apiClient.send(
                request,
                responseType: EmptyResponse.self
            )
        } catch APIClientError.httpError(let statusCode)
                    where statusCode == 409 {
            throw SyncError.conflict
        }
    }
}

private struct EmptyResponse: Decodable {}
