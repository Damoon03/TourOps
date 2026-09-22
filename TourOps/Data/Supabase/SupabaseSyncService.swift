//
//  SupabaseSyncService.swift
//  TourOps
//
//  Created by Damoon saber on 11/6/1405 AP.
//

import Foundation

final class SupabaseSyncService: SyncServiceProtocol {

    private let apiClient: APIClientProtocol
    private let requestBuilder: SyncRequestBuilderProtocol
    private let authService: SupabaseAuthService

    init(
        apiClient: APIClientProtocol,
        requestBuilder: SyncRequestBuilderProtocol,
        authService: SupabaseAuthService
    ) {
        self.apiClient = apiClient
        self.requestBuilder = requestBuilder
        self.authService = authService
    }

    func execute(
        _ operation: SyncOperation
    ) async throws {
        var request = try requestBuilder.build(
            from: operation
        )

        let accessToken = try await authService.accessToken()

        request.setValue(
            "Bearer \(accessToken)",
            forHTTPHeaderField: "Authorization"
        )

        if operation.operationType != .delete,
           let payload = operation.payload {

            let userID = try await authService.userID()

            request.httpBody = try payloadWithUserID(
                payload,
                userID: userID
            )
        }

        do {
            let _: [EmptyResponse] = try await apiClient.send(
                request,
                responseType: [EmptyResponse].self
            )
        } catch APIClientError.httpError(let statusCode)
                    where statusCode == 409 {
            throw SyncError.conflict
        }
    }
}

private extension SupabaseSyncService {

    func payloadWithUserID(
        _ payload: String,
        userID: UUID
    ) throws -> Data {
        guard
            let data = payload.data(using: .utf8),
            var object = try JSONSerialization.jsonObject(
                with: data
            ) as? [String: Any]
        else {
            throw SupabaseSyncError.invalidPayload
        }

        object["user_id"] = userID.uuidString

        return try JSONSerialization.data(
            withJSONObject: object
        )
    }
}

private struct EmptyResponse: Decodable {
}

enum SupabaseSyncError: Error {
    case invalidPayload
}
