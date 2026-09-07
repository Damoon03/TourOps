//
//  DefaultSyncServiceTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 16/6/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

@MainActor
struct DefaultSyncServiceTests {

    @Test
    func executeThrowsConflictForHTTP409() async throws {
        let apiClient = MockAPIClient()
        let requestBuilder = MockSyncRequestBuilder()

        apiClient.error = APIClientError.httpError(
            statusCode: 409
        )

        let service = DefaultSyncService(
            apiClient: apiClient,
            requestBuilder: requestBuilder
        )

        let operation = makeOperation()

        do {
            try await service.execute(operation)
            Issue.record("Expected SyncError.conflict")
        } catch SyncError.conflict {
            // Expected
        } catch {
            Issue.record(
                "Expected SyncError.conflict, got \(error)"
            )
        }
    }

    // MARK: - Helpers

    private func makeOperation() -> SyncOperation {
        SyncOperation(
            id: UUID(),
            entityID: UUID(),
            entityType: .show,
            operationType: .update,
            payload: nil,
            version: 2,
            createdAt: Date(),
            status: .pending,
            retryCount: 0
        )
    }
}

// MARK: - Mock API Client

@MainActor
private final class MockAPIClient: APIClientProtocol {

    var error: Error?

    func send<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        if let error {
            throw error
        }

        fatalError("MockAPIClient success response is not configured")
    }
}

// MARK: - Mock Request Builder

@MainActor
private final class MockSyncRequestBuilder:
    SyncRequestBuilderProtocol {

    func build(
        from operation: SyncOperation
    ) throws -> URLRequest {
        URLRequest(
            url: URL(string: "https://example.com")!
        )
    }
}
