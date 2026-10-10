//
//  SupabaseSyncServiceTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 7/6/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

struct SupabaseSyncServiceTests {

    @Test
    func updateSucceedsWhenServerReturnsRepresentation() async throws {

        let apiClient = MockAPIClient(
            response: .success
        )

        let requestBuilder = MockSyncRequestBuilder()

        let authService = MockAuthService()

        let service = SupabaseSyncService(
            apiClient: apiClient,
            requestBuilder: requestBuilder,
            authService: authService
        )

        let operation = makeUpdateOperation()

        try await service.execute(operation)

        #expect(apiClient.sendCallCount == 1)
        #expect(requestBuilder.buildCallCount == 1)
        #expect(authService.accessTokenCallCount == 1)
        #expect(authService.userIDCallCount == 0)
    }
    
    @Test
    func updateThrowsConflictWhenServerReturnsEmptyRepresentation() async {

        let apiClient = MockAPIClient(
            response: .empty
        )

        let requestBuilder = MockSyncRequestBuilder()

        let authService = MockAuthService()

        let service = SupabaseSyncService(
            apiClient: apiClient,
            requestBuilder: requestBuilder,
            authService: authService
        )

        let operation = makeUpdateOperation()

        do {
            try await service.execute(operation)

            Issue.record(
                "Expected SyncError.conflict"
            )

        } catch SyncError.conflict {
            // Expected.
        } catch {
            Issue.record(
                "Expected SyncError.conflict, got \(error)"
            )
        }
    }

    @Test
    func updateThrowsConflictForHTTP409() async {

        let apiClient = MockAPIClient(
            response: .http409
        )

        let requestBuilder = MockSyncRequestBuilder()

        let authService = MockAuthService()

        let service = SupabaseSyncService(
            apiClient: apiClient,
            requestBuilder: requestBuilder,
            authService: authService
        )

        let operation = makeUpdateOperation()

        do {
            try await service.execute(operation)

            Issue.record(
                "Expected SyncError.conflict"
            )

        } catch SyncError.conflict {
            // Expected.
        } catch {
            Issue.record(
                "Expected SyncError.conflict, got \(error)"
            )
        }
    }

    @Test
    func createTreatsHTTP409AsSuccessfulDuplicate() async throws {

        let apiClient = MockAPIClient(
            response: .http409
        )

        let requestBuilder = MockSyncRequestBuilder()

        let authService = MockAuthService()

        let service = SupabaseSyncService(
            apiClient: apiClient,
            requestBuilder: requestBuilder,
            authService: authService
        )

        let operation = makeCreateOperation()

        try await service.execute(operation)

        #expect(apiClient.sendCallCount == 1)
        #expect(requestBuilder.buildCallCount == 1)
    }

    @Test
    func deleteThrowsConflictWhenServerReturnsEmptyRepresentation() async {

        let apiClient = MockAPIClient(
            response: .empty
        )

        let requestBuilder = MockSyncRequestBuilder()

        let authService = MockAuthService()

        let service = SupabaseSyncService(
            apiClient: apiClient,
            requestBuilder: requestBuilder,
            authService: authService
        )

        let operation = makeDeleteOperation()

        do {
            try await service.execute(operation)

            Issue.record(
                "Expected SyncError.conflict"
            )

        } catch SyncError.conflict {
            // Expected.
        } catch {
            Issue.record(
                "Expected SyncError.conflict, got \(error)"
            )
        }
    }
}

private extension SupabaseSyncServiceTests {

    func makeUpdateOperation() -> SyncOperation {

        SyncOperation(
            id: UUID(),
            entityID: UUID(),
            entityType: .team,
            operationType: .update,
            payload: """
            {
                "id": "\(UUID().uuidString)",
                "name": "Northbound",
                "genre": "Rock",
                "country": "Iran",
                "city": "Rasht",
                "created_at": "2026-01-01T00:00:00Z",
                "version": 2
            }
            """,
            version: 2,
            createdAt: Date(),
            status: .pending,
            retryCount: 0
        )
    }

    func makeCreateOperation() -> SyncOperation {

        let entityID = UUID()

        return SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .team,
            operationType: .create,
            payload: """
            {
                "id": "\(entityID.uuidString)",
                "name": "Northbound",
                "genre": "Rock",
                "country": "Iran",
                "city": "Rasht",
                "created_at": "2026-01-01T00:00:00Z",
                "version": 1
            }
            """,
            version: 1,
            createdAt: Date(),
            status: .pending,
            retryCount: 0
        )
    }

    func makeDeleteOperation() -> SyncOperation {

        SyncOperation(
            id: UUID(),
            entityID: UUID(),
            entityType: .team,
            operationType: .delete,
            payload: nil,
            version: 2,
            createdAt: Date(),
            status: .pending,
            retryCount: 0
        )
    }
}

private final class MockAPIClient: APIClientProtocol {

    enum Response {
        case success
        case empty
        case http409
    }

    private let response: Response

    private(set) var sendCallCount = 0

    init(response: Response) {
        self.response = response
    }

    func send<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {

        sendCallCount += 1

        switch response {

        case .success:
            return try makeResponse(
                data: """
                [
                    {
                        "id": "\(UUID().uuidString)"
                    }
                ]
                """
            )

        case .empty:
            return try makeResponse(
                data: "[]"
            )

        case .http409:
            throw APIClientError.httpError(
                statusCode: 409
            )
        }
    }

    private func makeResponse<Response: Decodable>(
        data: String
    ) throws -> Response {

        try JSONCoding.decoder.decode(
            Response.self,
            from: Data(data.utf8)
        )
    }
}

private final class MockSyncRequestBuilder: SyncRequestBuilderProtocol {

    private(set) var buildCallCount = 0

    func build(
        from operation: SyncOperation
    ) throws -> URLRequest {

        buildCallCount += 1

        return URLRequest(
            url: URL(
                string: "https://example.com"
            )!
        )
    }
}

private final class MockAuthService: SyncAuthProviding {
    
    private(set) var accessTokenCallCount = 0
    private(set) var userIDCallCount = 0

    func accessToken() async throws -> String {

        accessTokenCallCount += 1

        return "test-access-token"
    }

    func userID() async throws -> UUID {

        userIDCallCount += 1

        return UUID()
    }
}
