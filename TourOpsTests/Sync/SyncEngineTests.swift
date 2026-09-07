//
//  SyncEngineTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

@MainActor
struct SyncEngineTests {

    // MARK: - Success

    @Test
    func syncSuccessfullyExecutesAndDeletesOperation() async throws {
        let repository = MockSyncOperationRepository()
        let service = MockSyncService()
        let operation = makeOperation()

        repository.operations = [operation]

        let engine = makeEngine(
            repository: repository,
            service: service
        )

        await engine.sync()

        #expect(service.executedOperations.count == 1)
        #expect(repository.deletedOperations.count == 1)
    }

    // MARK: - Retry

    @Test
    func syncReturnsOperationToPendingWhenRetryIsAvailable() async throws {
        let repository = MockSyncOperationRepository()
        let service = MockSyncService()

        service.error = TestError.executionFailed

        let operation = makeOperation(
            retryCount: 0
        )

        repository.operations = [operation]

        let engine = makeEngine(
            repository: repository,
            service: service
        )

        await engine.sync()

        #expect(repository.updatedOperations.count == 2)

        let processingOperation =
            repository.updatedOperations[0]

        let retryOperation =
            repository.updatedOperations[1]

        #expect(
            processingOperation.status == .processing
        )

        #expect(
            retryOperation.status == .pending
        )

        #expect(
            retryOperation.retryCount == 1
        )
    }

    @Test
    func syncMarksOperationFailedWhenRetryLimitReached() async throws {
        let repository = MockSyncOperationRepository()
        let service = MockSyncService()

        service.error = TestError.executionFailed

        let operation = makeOperation(
            retryCount: 3
        )

        repository.operations = [operation]

        let engine = makeEngine(
            repository: repository,
            service: service,
            retryPolicy: SyncRetryPolicy(
                maxRetryCount: 3
            )
        )

        await engine.sync()

        #expect(repository.updatedOperations.count == 2)

        let finalOperation =
            repository.updatedOperations.last

        #expect(
            finalOperation?.status == .failed
        )

        #expect(
            finalOperation?.retryCount == 4
        )
    }
    
    @Test
    func syncMarksOperationAsConflictWithoutRetrying() async throws {
        let repository = MockSyncOperationRepository()
        let service = MockSyncService()

        service.error = SyncError.conflict

        let operation = makeOperation(
            retryCount: 0
        )

        repository.operations = [operation]

        let engine = makeEngine(
            repository: repository,
            service: service
        )

        await engine.sync()

        #expect(repository.updatedOperations.count == 2)

        let processingOperation =
            repository.updatedOperations[0]

        let conflictOperation =
            repository.updatedOperations[1]

        #expect(
            processingOperation.status == .processing
        )

        #expect(
            conflictOperation.status == .conflict
        )

        #expect(
            conflictOperation.retryCount == 0
        )

        #expect(
            repository.deletedOperations.isEmpty
        )
    }

    // MARK: - Reducer Integration

    @Test
    func syncReducesOperationsBeforeExecution() async throws {
        let entityID = UUID()

        let create = SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .show,
            operationType: .create,
            payload: nil,
            version: 1,
            createdAt: Date(timeIntervalSince1970: 100),
            status: .pending,
            retryCount: 0
        )

        let update = SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .show,
            operationType: .update,
            payload: nil,
            version: 2,
            createdAt: Date(timeIntervalSince1970: 200),
            status: .pending,
            retryCount: 0
        )

        let (
            engine,
            _,
            service
        ) = try makeEngine(
            operations: [
                create,
                update
            ]
        )

        await engine.sync()

        #expect(
            service.executedOperations.count == 1
        )

        #expect(
            service.executedOperations.first?.operationType == .create
        )
    }

    // MARK: - Helpers

    private func makeEngine(
        repository: MockSyncOperationRepository,
        service: MockSyncService,
        retryPolicy: SyncRetryPolicy = SyncRetryPolicy(
            maxRetryCount: 3
        )
    ) -> SyncEngine {
        SyncEngine(
            syncOperationRepository: repository,
            syncService: service,
            retryPolicy: retryPolicy,
            operationReducer: SyncOperationReducer()
        )
    }

    private func makeEngine(
        operations: [SyncOperation]
    ) throws -> (
        engine: SyncEngine,
        repository: MockSyncOperationRepository,
        service: MockSyncService
    ) {
        let repository = MockSyncOperationRepository(
            operations: operations
        )

        let service = MockSyncService()

        let engine = makeEngine(
            repository: repository,
            service: service
        )

        return (
            engine,
            repository,
            service
        )
    }

    private func makeOperation(
        retryCount: Int = 0
    ) -> SyncOperation {
        SyncOperation(
            id: UUID(),
            entityID: UUID(),
            entityType: .show,
            operationType: .create,
            payload: nil,
            version: 1,
            createdAt: Date(),
            status: .pending,
            retryCount: retryCount
        )
    }
}

// MARK: - Mock Repository

@MainActor
private final class MockSyncOperationRepository:
    SyncOperationRepositoryProtocol {

    var operations: [SyncOperation]

    var updatedOperations: [SyncOperation] = []
    var deletedOperations: [SyncOperation] = []

    init(
        operations: [SyncOperation] = []
    ) {
        self.operations = operations
    }

    func fetchPendingOperations()
    async throws -> [SyncOperation] {
        operations
    }

    func add(
        _ operation: SyncOperation
    ) async throws {
        operations.append(operation)
    }

    func update(
        _ operation: SyncOperation
    ) async throws {
        updatedOperations.append(operation)
    }

    func delete(
        _ operation: SyncOperation
    ) async throws {
        deletedOperations.append(operation)
    }
}

// MARK: - Mock Service

@MainActor
private final class MockSyncService:
    SyncServiceProtocol {

    var executedOperations: [SyncOperation] = []
    var error: Error?

    func execute(
        _ operation: SyncOperation
    ) async throws {
        executedOperations.append(operation)

        if let error {
            throw error
        }
    }
}

// MARK: - Error

private enum TestError: Error {
    case executionFailed
}
