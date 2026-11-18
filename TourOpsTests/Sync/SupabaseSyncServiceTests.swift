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

    // MARK: - Create replay and HTTP 409

    @Test
    func createIsAppliedWhenHTTP409AndTheRowIsFound() async throws {

        let environment = makeEnvironment(
            response: .http409,
            readResponse: .success
        )

        try await environment.service.execute(makeCreateOperation())

        #expect(environment.apiClient.requests.count == 2)
    }

    @Test
    func bareHTTP409OnCreateFailsWhenTheRowIsNotFound() async {

        let environment = makeEnvironment(
            response: .http409,
            readResponse: .empty
        )

        do {
            try await environment.service.execute(makeCreateOperation())

            Issue.record("Expected SyncError.createNotConfirmed")

        } catch SyncError.createNotConfirmed {
            // Expected.
        } catch {
            Issue.record(
                "Expected SyncError.createNotConfirmed, got \(error)"
            )
        }
    }

    @Test
    func createPropagatesANetworkErrorFromTheConfirmingRead() async {

        let environment = makeEnvironment(
            response: .http409,
            readResponse: .networkError
        )

        do {
            try await environment.service.execute(makeCreateOperation())

            Issue.record("Expected APIClientError.networkError")

        } catch APIClientError.networkError {
            // Expected.
        } catch {
            Issue.record(
                "Expected APIClientError.networkError, got \(error)"
            )
        }
    }

    @Test
    func createPropagatesAServerErrorFromTheConfirmingRead() async {

        let environment = makeEnvironment(
            response: .http409,
            readResponse: .http500
        )

        do {
            try await environment.service.execute(makeCreateOperation())

            Issue.record("Expected APIClientError.httpError")

        } catch APIClientError.httpError(let statusCode) {
            #expect(statusCode == 500)
        } catch {
            Issue.record(
                "Expected APIClientError.httpError, got \(error)"
            )
        }
    }

    @Test
    func confirmingReadFiltersByIDAndOwnerAndCarriesTheAuthHeaders() async throws {

        let environment = makeEnvironment(
            response: .http409,
            readResponse: .success
        )

        let operation = makeCreateOperation()

        try await environment.service.execute(operation)

        let read = try #require(environment.apiClient.requests.last)

        let readURL = try #require(read.url)

        let components = try #require(
            URLComponents(
                url: readURL,
                resolvingAgainstBaseURL: false
            )
        )

        let items = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? []).map {
                ($0.name, $0.value ?? "")
            }
        )

        #expect(read.httpMethod == "GET")
        #expect(components.path == "/rest/v1/teams")
        #expect(items["id"] == "eq.\(operation.entityID.uuidString)")
        #expect(
            items["user_id"] == "eq.\(environment.authService.fixedUserID.uuidString)"
        )
        #expect(items["select"] == "id")
        #expect(read.httpBody == nil)
        #expect(read.value(forHTTPHeaderField: "apikey") == "test-api-key")
        #expect(
            read.value(forHTTPHeaderField: "Authorization")
                == "Bearer test-access-token"
        )
        #expect(read.value(forHTTPHeaderField: "Prefer") == nil)
    }

    @Test
    func createErrorsOtherThanHTTP409DoNotTriggerARead() async {

        for response in [
            MockAPIClient.Response.http500,
            MockAPIClient.Response.networkError
        ] {
            let environment = makeEnvironment(
                response: response,
                readResponse: .success
            )

            await #expect(throws: (any Error).self) {
                try await environment.service.execute(
                    makeCreateOperation()
                )
            }

            #expect(environment.apiClient.requests.count == 1)
        }
    }

    @Test
    func deleteHTTP409ThrowsConflictWithoutReading() async {

        let environment = makeEnvironment(
            response: .http409,
            readResponse: .success
        )

        do {
            try await environment.service.execute(makeDeleteOperation())

            Issue.record("Expected SyncError.conflict")

        } catch SyncError.conflict {
            #expect(environment.apiClient.requests.count == 1)
        } catch {
            Issue.record("Expected SyncError.conflict, got \(error)")
        }
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

    struct Environment {
        let service: SupabaseSyncService
        let apiClient: MockAPIClient
        let authService: MockAuthService
    }

    func makeEnvironment(
        response: MockAPIClient.Response,
        readResponse: MockAPIClient.Response
    ) -> Environment {

        let apiClient = MockAPIClient(
            response: response,
            readResponse: readResponse
        )

        let authService = MockAuthService()

        let service = SupabaseSyncService(
            apiClient: apiClient,
            requestBuilder: MockSyncRequestBuilder(),
            authService: authService
        )

        return Environment(
            service: service,
            apiClient: apiClient,
            authService: authService
        )
    }

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
        case http500
        case networkError
    }

    /// Answers the first request. Any later request is the confirming read
    /// of a create and gets `readResponse`.
    private let response: Response
    private let readResponse: Response

    private(set) var requests: [URLRequest] = []

    var sendCallCount: Int { requests.count }

    init(
        response: Response,
        readResponse: Response = .empty
    ) {
        self.response = response
        self.readResponse = readResponse
    }

    func send<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {

        let current = requests.isEmpty ? response : readResponse

        requests.append(request)

        switch current {

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

        case .http500:
            throw APIClientError.httpError(
                statusCode: 500
            )

        case .networkError:
            throw APIClientError.networkError(
                URLError(.notConnectedToInternet)
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

        var request = URLRequest(
            url: URL(
                string: "https://example.com/rest/v1/teams"
            )!
        )

        request.httpMethod = "POST"
        request.setValue("test-api-key", forHTTPHeaderField: "apikey")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        return request
    }
}

private final class MockAuthService: SyncAuthProviding {
    
    private(set) var accessTokenCallCount = 0
    private(set) var userIDCallCount = 0

    let fixedUserID = UUID()

    func accessToken() async throws -> String {

        accessTokenCallCount += 1

        return "test-access-token"
    }

    func userID() async throws -> UUID {

        userIDCallCount += 1

        return fixedUserID
    }
}
