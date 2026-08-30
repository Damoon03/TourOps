//
//  SyncEngineTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 9/8/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

@MainActor
struct SyncEngineTests {

    @Test
    func syncExecutesPendingOperations() async throws {
        let operation = makeOperation()
        let operationRepository = MockSyncOperationRepository(
            pendingOperations: [operation]
        )
        let syncService = MockSyncService()

        let engine = SyncEngine(
            syncOperationRepository: operationRepository,
            syncService: syncService
        )

        await engine.sync()

        #expect(syncService.executedOperations == [operation])
    }

    @Test
    func syncDeletesOperationAfterSuccessfulExecution() async throws {
        let operation = makeOperation()
        let operationRepository = MockSyncOperationRepository(
            pendingOperations: [operation]
        )
        let syncService = MockSyncService()

        let engine = SyncEngine(
            syncOperationRepository: operationRepository,
            syncService: syncService
        )

        await engine.sync()

        #expect(operationRepository.deletedOperations == [operation])
    }

    @Test
    func syncDoesNotDeleteOperationWhenExecutionFails() async throws {
        let operation = makeOperation()
        let operationRepository = MockSyncOperationRepository(
            pendingOperations: [operation]
        )
        let syncService = MockSyncService(
            shouldFail: true
        )

        let engine = SyncEngine(
            syncOperationRepository: operationRepository,
            syncService: syncService
        )

        await engine.sync()

        #expect(operationRepository.deletedOperations.isEmpty)
    }

    @Test
    func syncDoesNothingWhenThereAreNoPendingOperations() async throws {
        let operationRepository = MockSyncOperationRepository()
        let syncService = MockSyncService()

        let engine = SyncEngine(
            syncOperationRepository: operationRepository,
            syncService: syncService
        )

        await engine.sync()

        #expect(syncService.executedOperations.isEmpty)
        #expect(operationRepository.deletedOperations.isEmpty)
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

// MARK: - Mocks

@MainActor
private final class MockSyncOperationRepository:
    SyncOperationRepositoryProtocol {

    private(set) var pendingOperations: [SyncOperation]
    private(set) var deletedOperations: [SyncOperation] = []

    init(
        pendingOperations: [SyncOperation] = []
    ) {
        self.pendingOperations = pendingOperations
    }

    func add(_ operation: SyncOperation) async throws {
        pendingOperations.append(operation)
    }

    func fetchPendingOperations() async throws -> [SyncOperation] {
        pendingOperations
    }

    func update(_ operation: SyncOperation) async throws {
        if let index = pendingOperations.firstIndex(
            where: { $0.id == operation.id }
        ) {
            pendingOperations[index] = operation
        }
    }

    func delete(_ operation: SyncOperation) async throws {
        deletedOperations.append(operation)

        pendingOperations.removeAll {
            $0.id == operation.id
        }
    }
}

private final class MockSyncService: SyncServiceProtocol {

    private(set) var executedOperations: [SyncOperation] = []

    let shouldFail: Bool

    init(shouldFail: Bool = false) {
        self.shouldFail = shouldFail
    }

    func execute(
        _ operation: SyncOperation
    ) async throws {

        if shouldFail {
            throw MockSyncServiceError.executionFailed
        }

        executedOperations.append(operation)
    }
}

private enum MockSyncServiceError: Error {
    case executionFailed
}
