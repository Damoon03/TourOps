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

        let engine = SyncEngine(
            syncOperationRepository: repository,
            syncService: service
        )

        await engine.sync()

        #expect(service.executedOperations.count == 1)
        #expect(service.executedOperations.first?.id == operation.id)

        #expect(repository.updatedOperations.count == 1)
        #expect(
            repository.updatedOperations.first?.status == .processing
        )

        #expect(repository.deletedOperations.count == 1)
        #expect(repository.deletedOperations.first?.id == operation.id)
    }

    // MARK: - Failure

    @Test
    func syncMarksOperationAsFailedWhenExecutionFails() async throws {
        let repository = MockSyncOperationRepository()
        let service = MockSyncService()
        service.error = TestError.executionFailed

        let operation = makeOperation()
        repository.operations = [operation]

        let engine = SyncEngine(
            syncOperationRepository: repository,
            syncService: service
        )

        await engine.sync()

        #expect(service.executedOperations.count == 1)

        #expect(repository.updatedOperations.count == 2)
        #expect(
            repository.updatedOperations[0].status == .processing
        )
        #expect(
            repository.updatedOperations[1].status == .failed
        )

        #expect(repository.deletedOperations.isEmpty)
    }

    // MARK: - Multiple Operations

    @Test
    func syncProcessesAllPendingOperations() async throws {
        let repository = MockSyncOperationRepository()
        let service = MockSyncService()

        let first = makeOperation()
        let second = makeOperation()
        let third = makeOperation()

        repository.operations = [
            first,
            second,
            third
        ]

        let engine = SyncEngine(
            syncOperationRepository: repository,
            syncService: service
        )

        await engine.sync()

        #expect(service.executedOperations.count == 3)
        #expect(repository.deletedOperations.count == 3)
        #expect(repository.updatedOperations.count == 3)
    }

    // MARK: - Helpers

    private func makeOperation() -> SyncOperation {
        SyncOperation(
            id: UUID(),
            entityID: UUID(),
            entityType: .show,
            operationType: .create,
            createdAt: Date(),
            status: .pending,
            retryCount: 0
        )
    }
}

// MARK: - Mock Sync Operation Repository

@MainActor
private final class MockSyncOperationRepository:
    SyncOperationRepositoryProtocol {

    var operations: [SyncOperation] = []
    var updatedOperations: [SyncOperation] = []
    var deletedOperations: [SyncOperation] = []

    func fetchPendingOperations() async throws -> [SyncOperation] {
        operations
    }

    func add(_ operation: SyncOperation) async throws {
        operations.append(operation)
    }

    func update(_ operation: SyncOperation) async throws {
        updatedOperations.append(operation)
    }

    func delete(_ operation: SyncOperation) async throws {
        deletedOperations.append(operation)
    }
}

// MARK: - Mock Sync Service

@MainActor
private final class MockSyncService: SyncServiceProtocol {

    var executedOperations: [SyncOperation] = []
    var error: Error?

    func execute(_ operation: SyncOperation) async throws {
        executedOperations.append(operation)

        if let error {
            throw error
        }
    }
}

// MARK: - Test Error

private enum TestError: Error {
    case executionFailed
}
