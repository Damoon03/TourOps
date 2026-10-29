//
//  SyncTrackingTourRepositoryTests.swift
//  TourOps
//
//  Created by Damoon saber on 9/6/1405 AP.
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct SyncTrackingTourRepositoryTests {

    // MARK: - Create

    @Test
    func createTourPersistsTourAndSyncOperation() async throws {

        let (repository, syncOperationRepository, syncScheduler) =
            try makeRepository()

        let tour = makeTour()

        try await repository.createTour(tour)

        #expect(syncScheduler.scheduleSyncCallCount == 1)

        let persistedTour = try await repository.fetchTour(
            id: tour.id
        )

        let operations = try await syncOperationRepository
            .fetchPendingOperations()

        #expect(persistedTour == tour)
        #expect(operations.count == 1)

        let operation = try #require(operations.first)

        #expect(operation.entityID == tour.id)
        #expect(operation.entityType == .tour)
        #expect(operation.operationType == .create)
        #expect(operation.version == tour.version)
        #expect(operation.status == .pending)
        #expect(operation.retryCount == 0)

        let payload = try #require(operation.payload)

        let payloadData = try #require(
            payload.data(using: .utf8)
        )

        let dto = try JSONCoding.decoder.decode(
            TourDTO.self,
            from: payloadData
        )

        #expect(dto.id == tour.id)
        #expect(dto.teamID == tour.teamID)
        #expect(dto.name == tour.name)
        #expect(dto.startDate == tour.startDate)
        #expect(dto.endDate == tour.endDate)
        #expect(dto.createdAt == tour.createdAt)
        #expect(dto.version == tour.version)
    }

    // MARK: - Update

    @Test
    func updateTourPersistsTourAndCreatesSyncOperation() async throws {

        let (repository, syncOperationRepository, syncScheduler) =
            try makeRepository()

        let tour = makeTour()

        try await repository.createTour(tour)

        let updatedTour = Tour(
            id: tour.id,
            teamID: tour.teamID,
            name: "Updated Tour",
            startDate: tour.startDate,
            endDate: tour.endDate,
            createdAt: tour.createdAt,
            version: tour.version
        )

        try await repository.updateTour(updatedTour)

        #expect(syncScheduler.scheduleSyncCallCount == 2)

        let persistedTour = try await repository.fetchTour(
            id: tour.id
        )

        let operations = try await syncOperationRepository
            .fetchPendingOperations()

        #expect(persistedTour.name == "Updated Tour")
        #expect(persistedTour.version == 3)
        #expect(operations.count == 2)

        let updateOperations = operations.filter {
            $0.operationType == .update
        }

        #expect(updateOperations.count == 1)

        let operation = try #require(updateOperations.first)

        #expect(operation.entityID == tour.id)
        #expect(operation.entityType == .tour)
        #expect(operation.operationType == .update)

        #expect(operation.version == tour.version)

        #expect(operation.status == .pending)
        #expect(operation.retryCount == 0)

        let payload = try #require(operation.payload)

        let payloadData = try #require(
            payload.data(using: .utf8)
        )

        let dto = try JSONCoding.decoder.decode(
            TourDTO.self,
            from: payloadData
        )

        #expect(dto.id == updatedTour.id)
        #expect(dto.teamID == updatedTour.teamID)
        #expect(dto.name == updatedTour.name)
        #expect(dto.startDate == updatedTour.startDate)
        #expect(dto.endDate == updatedTour.endDate)
        #expect(dto.createdAt == updatedTour.createdAt)
        #expect(dto.version == tour.version + 1)
    }

    // MARK: - Delete

    @Test
    func deleteTourDeletesTourAndCreatesSyncOperation() async throws {

        let (repository, syncOperationRepository, syncScheduler) =
            try makeRepository()

        let tour = makeTour()

        try await repository.createTour(tour)

        try await repository.deleteTour(id: tour.id)

        #expect(syncScheduler.scheduleSyncCallCount == 2)

        await #expect(throws: RepositoryError.notFound) {
            try await repository.fetchTour(id: tour.id)
        }

        let operations = try await syncOperationRepository
            .fetchPendingOperations()

        #expect(operations.count == 2)

        let deleteOperations = operations.filter {
            $0.operationType == .delete
        }

        #expect(deleteOperations.count == 1)

        let operation = try #require(deleteOperations.first)

        #expect(operation.entityID == tour.id)
        #expect(operation.entityType == .tour)
        #expect(operation.operationType == .delete)

        #expect(operation.version == tour.version)

        #expect(operation.status == .pending)
        #expect(operation.retryCount == 0)
        #expect(operation.payload == nil)
    }

    // MARK: - Unresolved sync issues

    @Test(arguments: [SyncOperationStatus.conflict, SyncOperationStatus.failed])
    func updateTourIsRejectedWhileAnUnresolvedOperationExists(
        status: SyncOperationStatus
    ) async throws {

        let blocked = try await makeBlockedTour(status: status)
        let scheduleCount = blocked.syncScheduler.scheduleSyncCallCount

        await #expect(throws: RepositoryError.unresolvedSyncIssue) {
            try await blocked.repository.updateTour(
                edited(blocked.tour, name: "Second Edit")
            )
        }

        let persisted = try await blocked.repository.fetchTour(
            id: blocked.tour.id
        )

        #expect(persisted.name == "First Edit")
        #expect(persisted.version == blocked.tour.version)

        let operations = try await blocked.syncOperationRepository
            .fetchOperations(forEntityID: blocked.tour.id)

        // The blocking operation is kept exactly as it was, and nothing new
        // is queued.
        #expect(operations.count == 2)
        #expect(operations.contains(blocked.blockedOperation))
        #expect(blocked.syncScheduler.scheduleSyncCallCount == scheduleCount)
    }

    @Test(arguments: [SyncOperationStatus.conflict, SyncOperationStatus.failed])
    func deleteTourIsRejectedWhileAnUnresolvedOperationExists(
        status: SyncOperationStatus
    ) async throws {

        let blocked = try await makeBlockedTour(status: status)
        let scheduleCount = blocked.syncScheduler.scheduleSyncCallCount

        await #expect(throws: RepositoryError.unresolvedSyncIssue) {
            try await blocked.repository.deleteTour(id: blocked.tour.id)
        }

        let persisted = try await blocked.repository.fetchTour(
            id: blocked.tour.id
        )

        #expect(persisted.version == blocked.tour.version)

        let operations = try await blocked.syncOperationRepository
            .fetchOperations(forEntityID: blocked.tour.id)

        #expect(operations.count == 2)
        #expect(operations.contains(blocked.blockedOperation))
        #expect(blocked.syncScheduler.scheduleSyncCallCount == scheduleCount)
    }

    @Test
    func unresolvedOperationOnOneTourDoesNotBlockAnother() async throws {

        let blocked = try await makeBlockedTour(status: .conflict)

        let other = makeTour()
        let otherEntity = Tour(id: UUID(), teamID: other.teamID, name: "Other", startDate: other.startDate, endDate: other.endDate, createdAt: other.createdAt, version: other.version)

        try await blocked.repository.createTour(otherEntity)
        try await blocked.repository.updateTour(
            edited(otherEntity, name: "Other Edit")
        )

        let persisted = try await blocked.repository.fetchTour(
            id: otherEntity.id
        )

        #expect(persisted.name == "Other Edit")
    }

    @Test
    func updateTourWorksAgainOnceTheBlockingOperationIsRemoved() async throws {

        let blocked = try await makeBlockedTour(status: .conflict)

        // Part B will remove operations through an explicit user action. The
        // test removes it directly only to show the guard is not sticky.
        try await blocked.syncOperationRepository.delete(
            blocked.blockedOperation
        )

        try await blocked.repository.updateTour(
            edited(blocked.tour, name: "Second Edit")
        )

        let persisted = try await blocked.repository.fetchTour(
            id: blocked.tour.id
        )

        #expect(persisted.name == "Second Edit")
        #expect(persisted.version == blocked.tour.version + 1)
    }

    // MARK: - Helpers

    private func makeRepository() throws -> (
        repository: SyncTrackingTourRepository,
        syncOperationRepository: SwiftDataSyncOperationRepository,
        syncScheduler: MockSyncScheduler
    ) {

        let schema = Schema([
            TourEntity.self,
            SyncOperationEntity.self
        ])

        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        let container = try ModelContainer(
            for: schema,
            configurations: configuration
        )

        let modelContext = ModelContext(container)

        let tourRepository = SwiftDataTourRepository(
            modelContext: modelContext
        )

        let syncOperationRepository =
            SwiftDataSyncOperationRepository(
                modelContext: modelContext
            )

        let syncScheduler = MockSyncScheduler()

        let repository = SyncTrackingTourRepository(
            tourRepository: tourRepository,
            syncOperationRepository: syncOperationRepository,
            modelContext: modelContext,
            syncScheduler: syncScheduler
        )

        return (
            repository,
            syncOperationRepository,
            syncScheduler
        )
    }

    private func makeBlockedTour(
        status: SyncOperationStatus
    ) async throws -> (
        repository: SyncTrackingTourRepository,
        syncOperationRepository: SwiftDataSyncOperationRepository,
        syncScheduler: MockSyncScheduler,
        tour: Tour,
        blockedOperation: SyncOperation
    ) {

        let (repository, syncOperationRepository, syncScheduler) =
            try makeRepository()

        let created = makeTour()

        try await repository.createTour(created)
        try await repository.updateTour(
            edited(created, name: "First Edit")
        )

        let pending = try await syncOperationRepository
            .fetchPendingOperations()

        let updateOperation = pending.first {
            $0.operationType == .update
        }

        var blockedOperation = try #require(updateOperation)

        blockedOperation.status = status

        try await syncOperationRepository.update(blockedOperation)

        let current = try await repository.fetchTour(id: created.id)

        return (
            repository,
            syncOperationRepository,
            syncScheduler,
            current,
            blockedOperation
        )
    }

    private func edited(_ tour: Tour, name: String) -> Tour {

        Tour(
            id: tour.id,
            teamID: tour.teamID,
            name: name,
            startDate: tour.startDate,
            endDate: tour.endDate,
            createdAt: tour.createdAt,
            version: tour.version
        )
    }

    private func makeTour() -> Tour {

        Tour(
            id: UUID(),
            teamID: UUID(),
            name: "Test Tour",
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000),
            createdAt: Date(timeIntervalSince1970: 900),
            version: 2
        )
    }
}
