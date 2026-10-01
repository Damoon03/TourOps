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

    @Test
    func syncKeepsOperationWhenLocalDeleteFails() async throws {
        let repository = MockSyncOperationRepository()
        let service = MockSyncService()

        repository.deleteError = TestError.persistenceFailed

        let operation = makeOperation()
        repository.operations = [operation]

        let engine = makeEngine(
            repository: repository,
            service: service
        )

        await engine.sync()

        #expect(service.executedOperations.count == 1)
        #expect(repository.deletedOperations.isEmpty)

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

    // MARK: - Cancellation

    @Test
    func syncDoesNothingWhenTaskIsAlreadyCancelled() async throws {
        let repository = MockSyncOperationRepository()
        let service = MockSyncService()

        let operation = makeOperation()

        repository.operations = [operation]

        let engine = makeEngine(
            repository: repository,
            service: service
        )

        let task = Task {
            await engine.sync()
        }

        task.cancel()

        await task.value

        #expect(service.executedOperations.isEmpty)
        #expect(repository.updatedOperations.isEmpty)
        #expect(repository.deletedOperations.isEmpty)
    }

    @Test
    func syncReturnsOperationToPendingWhenCancelled() async throws {
        let repository = MockSyncOperationRepository()
        let service = MockSyncService()

        service.error = CancellationError()

        let operation = makeOperation(
            retryCount: 0
        )

        repository.operations = [operation]

        let engine = makeEngine(
            repository: repository,
            service: service
        )

        await engine.sync()

        #expect(service.executedOperations.count == 1)
        #expect(repository.updatedOperations.count == 2)

        let processingOperation =
            repository.updatedOperations[0]

        let pendingOperation =
            repository.updatedOperations[1]

        #expect(
            processingOperation.status == .processing
        )

        #expect(
            pendingOperation.status == .pending
        )

        #expect(
            pendingOperation.retryCount == 0
        )

        #expect(
            repository.deletedOperations.isEmpty
        )
    }

    // MARK: - Lost Wake-up

    @Test
    func syncRunsAgainWhenRequestedWhileAlreadySyncing() async throws {
        let repository = MockSyncOperationRepository()
        let service = MockSyncService()

        service.shouldPauseFirstExecution = true

        let firstOperation = makeOperation()
        let secondOperation = makeOperation()

        repository.operations = [
            firstOperation
        ]

        let engine = makeEngine(
            repository: repository,
            service: service
        )

        let firstSync = Task {
            await engine.sync()
        }

        await service.waitUntilFirstExecutionStarts()

        repository.operations = [
            secondOperation
        ]

        await engine.sync()

        service.resumeFirstExecution()

        await firstSync.value

        #expect(
            service.executedOperations.count == 2
        )

        #expect(
            service.executedOperations[0].id == firstOperation.id
        )

        #expect(
            service.executedOperations[1].id == secondOperation.id
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

    @Test
    func syncRemovesSupersededOperationsAfterSuccessfulExecution() async throws {
        let entityID = UUID()

        let firstUpdate = SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .show,
            operationType: .update,
            payload: nil,
            version: 1,
            createdAt: Date(timeIntervalSince1970: 100),
            status: .pending,
            retryCount: 0
        )

        let secondUpdate = SyncOperation(
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

        let latestUpdate = SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .show,
            operationType: .update,
            payload: nil,
            version: 3,
            createdAt: Date(timeIntervalSince1970: 300),
            status: .pending,
            retryCount: 0
        )

        let repository = MockSyncOperationRepository(
            operations: [
                firstUpdate,
                secondUpdate,
                latestUpdate
            ]
        )

        let service = MockSyncService()

        let engine = makeEngine(
            repository: repository,
            service: service
        )

        await engine.sync()

        #expect(
            service.executedOperations.count == 1
        )

        #expect(
            service.executedOperations.first?.version == 3
        )

        #expect(
            repository.operations.isEmpty
        )
    }

    @Test
    func syncRemovesCreateAndDeleteOperationsWithoutExecution() async throws {
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

        let delete = SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .show,
            operationType: .delete,
            payload: nil,
            version: 1,
            createdAt: Date(timeIntervalSince1970: 200),
            status: .pending,
            retryCount: 0
        )

        let repository = MockSyncOperationRepository(
            operations: [
                create,
                delete
            ]
        )

        let service = MockSyncService()

        let engine = makeEngine(
            repository: repository,
            service: service
        )

        await engine.sync()

        #expect(
            service.executedOperations.isEmpty
        )

        #expect(
            repository.deletedOperations.count == 2
        )

        #expect(
            repository.operations.isEmpty
        )
    }

    @Test
    func syncCleansUpNoOpOperationsAndExecutesRemainingOperations() async throws {
        let firstEntityID = UUID()
        let secondEntityID = UUID()

        let create = SyncOperation(
            id: UUID(),
            entityID: firstEntityID,
            entityType: .show,
            operationType: .create,
            payload: nil,
            version: 1,
            createdAt: Date(timeIntervalSince1970: 100),
            status: .pending,
            retryCount: 0
        )

        let delete = SyncOperation(
            id: UUID(),
            entityID: firstEntityID,
            entityType: .show,
            operationType: .delete,
            payload: nil,
            version: 1,
            createdAt: Date(timeIntervalSince1970: 200),
            status: .pending,
            retryCount: 0
        )

        let update = SyncOperation(
            id: UUID(),
            entityID: secondEntityID,
            entityType: .show,
            operationType: .update,
            payload: nil,
            version: 1,
            createdAt: Date(timeIntervalSince1970: 300),
            status: .pending,
            retryCount: 0
        )

        let repository = MockSyncOperationRepository(
            operations: [
                create,
                delete,
                update
            ]
        )

        let service = MockSyncService()

        let engine = makeEngine(
            repository: repository,
            service: service
        )

        await engine.sync()

        #expect(
            service.executedOperations.count == 1
        )

        #expect(
            service.executedOperations.first?.entityID == secondEntityID
        )

        #expect(
            repository.deletedOperations.count == 3
        )

        #expect(
            repository.operations.isEmpty
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
    var deleteError: Error?

    init(
        operations: [SyncOperation] = []
    ) {
        self.operations = operations
    }

    func fetchPendingOperations()
        async throws -> [SyncOperation] {
        operations.filter {
            $0.status == .pending
        }
    }

    func fetchOperations(
        forEntityID entityID: UUID
    ) async throws -> [SyncOperation] {
        operations.filter {
            $0.entityID == entityID
        }
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

        if let index = operations.firstIndex(
            where: { $0.id == operation.id }
        ) {
            operations[index] = operation
        }
    }

    func delete(
        _ operation: SyncOperation
    ) async throws {
        if let deleteError {
            throw deleteError
        }

        deletedOperations.append(operation)

        operations.removeAll {
            $0.id == operation.id
        }
    }
}

// MARK: - Mock Service

@MainActor
private final class MockSyncService:

    SyncServiceProtocol {

    var executedOperations: [SyncOperation] = []
    var error: Error?

    var shouldPauseFirstExecution = false

    private var firstExecutionContinuation:
        CheckedContinuation<Void, Never>?

    private var executeStartedContinuation:
        CheckedContinuation<Void, Never>?

    private var firstExecutionStarted = false

    func waitUntilFirstExecutionStarts() async {
        if firstExecutionStarted {
            return
        }

        await withCheckedContinuation { continuation in
            executeStartedContinuation = continuation
        }
    }

    func resumeFirstExecution() {
        firstExecutionContinuation?.resume()
        firstExecutionContinuation = nil
    }

    func execute(
        _ operation: SyncOperation
    ) async throws {
        executedOperations.append(operation)

        if shouldPauseFirstExecution &&
            executedOperations.count == 1 {

            await withCheckedContinuation { continuation in
                firstExecutionContinuation = continuation
                firstExecutionStarted = true

                executeStartedContinuation?.resume()
                executeStartedContinuation = nil
            }
        }

        if let error {
            throw error
        }
    }
}

// MARK: - Error

private enum TestError: Error {
    case executionFailed
    case persistenceFailed
}
