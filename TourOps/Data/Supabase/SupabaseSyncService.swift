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
    private let authService: SyncAuthProviding

    init(
        apiClient: APIClientProtocol,
        requestBuilder: SyncRequestBuilderProtocol,
        authService: SyncAuthProviding
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

        var createUserID: UUID?

        if operation.operationType == .create,
           let payload = operation.payload {

            let userID = try await authService.userID()
            createUserID = userID

            request.httpBody = try payloadWithUserID(
                payload,
                userID: userID
            )

        } else if operation.operationType == .update,
                  let payload = operation.payload {

            request.httpBody = payload.data(
                using: .utf8
            )
        }

        do {

            let representation: [EmptyResponse] = try await apiClient.send(
                request,
                responseType: [EmptyResponse].self
            )

            if (operation.operationType == .update
                || operation.operationType == .delete),
               representation.isEmpty {

                throw SyncError.conflict
            }

        } catch APIClientError.httpError(let statusCode)
                    where statusCode == 409 {

            guard operation.operationType == .create else {
                throw SyncError.conflict
            }

            // A 409 on a create can be a replay or a real rejection (for
            // example a foreign-key violation). Only the row itself shows
            // which, so the create counts as applied only if it is found.
            guard let userID = createUserID else {
                throw SyncError.createNotConfirmed
            }

            try await confirmCreateApplied(
                createRequest: request,
                entityID: operation.entityID,
                userID: userID
            )
        }
    }
}

private extension SupabaseSyncService {

    /// Reads the row back by id and owner, reusing the create request's URL
    /// and auth headers. Errors from the read propagate unchanged.
    func confirmCreateApplied(
        createRequest: URLRequest,
        entityID: UUID,
        userID: UUID
    ) async throws {

        guard
            let url = createRequest.url,
            var components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: true
            )
        else {
            throw SyncError.createNotConfirmed
        }

        components.queryItems = [
            URLQueryItem(name: "id", value: "eq.\(entityID.uuidString)"),
            URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"),
            URLQueryItem(name: "select", value: "id")
        ]

        guard let readURL = components.url else {
            throw SyncError.createNotConfirmed
        }

        var readRequest = URLRequest(url: readURL)
        readRequest.httpMethod = HTTPMethod.GET.rawValue

        for header in ["apikey", "Authorization"] {
            readRequest.setValue(
                createRequest.value(forHTTPHeaderField: header),
                forHTTPHeaderField: header
            )
        }

        let rows: [EmptyResponse] = try await apiClient.send(
            readRequest,
            responseType: [EmptyResponse].self
        )

        guard !rows.isEmpty else {
            throw SyncError.createNotConfirmed
        }
    }

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
