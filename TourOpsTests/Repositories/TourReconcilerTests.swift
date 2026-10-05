//
//  TourReconcilerTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 7/13/1405 AP.
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct TourReconcilerTests {

    private let container: ModelContainer
    private let tourRepository: SwiftDataTourRepository
    private let syncOperationRepository: MockSyncOperationRepository
    private let reconciler: TourReconciler

    init() throws {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        self.container = try ModelContainer(
            for: TourEntity.self,
            configurations: configuration
        )

        self.tourRepository = SwiftDataTourRepository(
            modelContext: container.mainContext
        )

        self.syncOperationRepository = MockSyncOperationRepository()

        self.reconciler = TourReconciler(
            tourRepository: tourRepository,
            syncOperationRepository: syncOperationRepository
        )
    }

    // MARK: - Remote Update

    @Test
    func remoteNewerTourUpdatesLocalTour() async throws {
        let localTour = makeTour(
            name: "European Tour",
            version: 1
        )

        try await tourRepository.createTour(localTour)

        let remoteTour = makeTour(
            id: localTour.id,
            name: "Updated European Tour",
            version: 2
        )

        try await reconciler.reconcile(
            remoteTours: [remoteTour]
        )

        let updatedTour = try await tourRepository.fetchTour(
            id: localTour.id
        )

        #expect(updatedTour.name == "Updated European Tour")
        #expect(updatedTour.version == 2)
    }

    @Test
    func remoteOlderTourDoesNotUpdateLocalTour() async throws {
        let localTour = makeTour(
            name: "Local Tour",
            version: 2
        )

        try await tourRepository.createTour(localTour)

        let remoteTour = makeTour(
            id: localTour.id,
            name: "Older Remote Tour",
            version: 1
        )

        try await reconciler.reconcile(
            remoteTours: [remoteTour]
        )

        let fetchedTour = try await tourRepository.fetchTour(
            id: localTour.id
        )

        #expect(fetchedTour.name == "Local Tour")
        #expect(fetchedTour.version == 2)
    }

    @Test
    func remoteEqualVersionDoesNotUpdateLocalTour() async throws {
        let localTour = makeTour(
            name: "Local Tour",
            version: 2
        )

        try await tourRepository.createTour(localTour)

        let remoteTour = makeTour(
            id: localTour.id,
            name: "Equal Version Remote Tour",
            version: 2
        )

        try await reconciler.reconcile(
            remoteTours: [remoteTour]
        )

        let fetchedTour = try await tourRepository.fetchTour(
            id: localTour.id
        )

        #expect(fetchedTour.name == "Local Tour")
        #expect(fetchedTour.version == 2)
    }

    // MARK: - Remote Create

    @Test
    func remoteOnlyTourIsCreatedLocally() async throws {
        let remoteTour = makeTour(
            name: "Remote Tour",
            version: 1
        )

        try await reconciler.reconcile(
            remoteTours: [remoteTour]
        )

        let createdTour = try await tourRepository.fetchTour(
            id: remoteTour.id
        )

        #expect(createdTour == remoteTour)
    }

    // MARK: - Blocking Operations

    @Test
    func pendingOperationPreservesLocalTour() async throws {
        let localTour = makeTour(
            name: "Local Tour",
            version: 1
        )

        try await tourRepository.createTour(localTour)

        syncOperationRepository.operations = [
            makeOperation(
                entityID: localTour.id,
                operationType: .update,
                status: .pending
            )
        ]

        let remoteTour = makeTour(
            id: localTour.id,
            name: "Remote Tour",
            version: 2
        )

        try await reconciler.reconcile(
            remoteTours: [remoteTour]
        )

        let fetchedTour = try await tourRepository.fetchTour(
            id: localTour.id
        )

        #expect(fetchedTour.name == "Local Tour")
        #expect(fetchedTour.version == 1)
    }

    @Test
    func processingOperationPreservesLocalTour() async throws {
        let localTour = makeTour(
            name: "Local Tour",
            version: 1
        )

        try await tourRepository.createTour(localTour)

        syncOperationRepository.operations = [
            makeOperation(
                entityID: localTour.id,
                operationType: .update,
                status: .processing
            )
        ]

        let remoteTour = makeTour(
            id: localTour.id,
            name: "Remote Tour",
            version: 2
        )

        try await reconciler.reconcile(
            remoteTours: [remoteTour]
        )

        let fetchedTour = try await tourRepository.fetchTour(
            id: localTour.id
        )

        #expect(fetchedTour.name == "Local Tour")
        #expect(fetchedTour.version == 1)
    }

    @Test
    func conflictOperationPreservesLocalTour() async throws {
        let localTour = makeTour(
            name: "Local Tour",
            version: 1
        )

        try await tourRepository.createTour(localTour)

        syncOperationRepository.operations = [
            makeOperation(
                entityID: localTour.id,
                operationType: .update,
                status: .conflict
            )
        ]

        let remoteTour = makeTour(
            id: localTour.id,
            name: "Remote Tour",
            version: 2
        )

        try await reconciler.reconcile(
            remoteTours: [remoteTour]
        )

        let fetchedTour = try await tourRepository.fetchTour(
            id: localTour.id
        )

        #expect(fetchedTour.name == "Local Tour")
        #expect(fetchedTour.version == 1)
    }

    @Test
    func failedOperationAllowsRemoteTourToWin() async throws {
        let localTour = makeTour(
            name: "Local Tour",
            version: 1
        )

        try await tourRepository.createTour(localTour)

        syncOperationRepository.operations = [
            makeOperation(
                entityID: localTour.id,
                operationType: .update,
                status: .failed
            )
        ]

        let remoteTour = makeTour(
            id: localTour.id,
            name: "Remote Tour",
            version: 2
        )

        try await reconciler.reconcile(
            remoteTours: [remoteTour]
        )

        let fetchedTour = try await tourRepository.fetchTour(
            id: localTour.id
        )

        #expect(fetchedTour.name == "Remote Tour")
        #expect(fetchedTour.version == 2)
    }

    // MARK: - Remote Deletion

    @Test
    func localOnlyTourIsDeletedWhenThereIsNoOperation() async throws {
        let localTour = makeTour(
            name: "Local Tour",
            version: 1
        )

        try await tourRepository.createTour(localTour)

        try await reconciler.reconcile(
            remoteTours: []
        )

        await #expect(throws: RepositoryError.notFound) {
            try await tourRepository.fetchTour(id: localTour.id)
        }
    }

    @Test
    func pendingDeletePreservesLocalOnlyTour() async throws {
        let localTour = makeTour(
            name: "Local Tour",
            version: 1
        )

        try await tourRepository.createTour(localTour)

        syncOperationRepository.operations = [
            makeOperation(
                entityID: localTour.id,
                operationType: .delete,
                status: .pending
            )
        ]

        try await reconciler.reconcile(
            remoteTours: []
        )

        let fetchedTour = try await tourRepository.fetchTour(
            id: localTour.id
        )

        #expect(fetchedTour == localTour)
    }

    @Test
    func processingDeletePreservesLocalOnlyTour() async throws {
        let localTour = makeTour(
            name: "Local Tour",
            version: 1
        )

        try await tourRepository.createTour(localTour)

        syncOperationRepository.operations = [
            makeOperation(
                entityID: localTour.id,
                operationType: .delete,
                status: .processing
            )
        ]

        try await reconciler.reconcile(
            remoteTours: []
        )

        let fetchedTour = try await tourRepository.fetchTour(
            id: localTour.id
        )

        #expect(fetchedTour == localTour)
    }

    @Test
    func conflictPreservesLocalOnlyTour() async throws {
        let localTour = makeTour(
            name: "Local Tour",
            version: 1
        )

        try await tourRepository.createTour(localTour)

        syncOperationRepository.operations = [
            makeOperation(
                entityID: localTour.id,
                operationType: .update,
                status: .conflict
            )
        ]

        try await reconciler.reconcile(
            remoteTours: []
        )

        let fetchedTour = try await tourRepository.fetchTour(
            id: localTour.id
        )

        #expect(fetchedTour == localTour)
    }

    @Test
    func failedOperationDeletesLocalOnlyTour() async throws {
        let localTour = makeTour(
            name: "Local Tour",
            version: 1
        )

        try await tourRepository.createTour(localTour)

        syncOperationRepository.operations = [
            makeOperation(
                entityID: localTour.id,
                operationType: .update,
                status: .failed
            )
        ]

        try await reconciler.reconcile(
            remoteTours: []
        )

        await #expect(throws: RepositoryError.notFound) {
            try await tourRepository.fetchTour(id: localTour.id)
        }
    }

    // MARK: - Helpers

    private func makeTour(
        id: UUID = UUID(),
        name: String,
        version: Int
    ) -> Tour {
        Tour(
            id: id,
            teamID: UUID(),
            name: name,
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: version
        )
    }

    private func makeOperation(
        entityID: UUID,
        operationType: SyncOperationType,
        status: SyncOperationStatus
    ) -> SyncOperation {
        SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .tour,
            operationType: operationType,
            payload: nil,
            version: 1,
            createdAt: Date(),
            status: status,
            retryCount: 0
        )
    }
}

// MARK: - Mock

@MainActor
private final class MockSyncOperationRepository: SyncOperationRepositoryProtocol {

    var operations: [SyncOperation] = []

    func fetchPendingOperations() async throws -> [SyncOperation] {
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

    func add(_ operation: SyncOperation) async throws {
        operations.append(operation)
    }

    func update(_ operation: SyncOperation) async throws {
        guard let index = operations.firstIndex(
            where: { $0.id == operation.id }
        ) else {
            return
        }

        operations[index] = operation
    }

    func delete(_ operation: SyncOperation) async throws {
        operations.removeAll {
            $0.id == operation.id
        }
    }
}
