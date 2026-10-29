//
//  SyncTrackingShowRepositoryTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 9/9/1405 AP.
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct SyncTrackingShowRepositoryTests {

    // MARK: - Create

    @Test
    func createShowPersistsShowAndSyncOperation() async throws {

        let (repository, modelContext, syncScheduler) =
            try makeRepository()

        let show = makeShow()

        try await repository.createShow(show)

        #expect(syncScheduler.scheduleSyncCallCount == 1)

        let showDescriptor = FetchDescriptor<ShowEntity>()
        let operationDescriptor = FetchDescriptor<SyncOperationEntity>()

        let shows = try modelContext.fetch(showDescriptor)
        let operations = try modelContext.fetch(operationDescriptor)

        #expect(shows.count == 1)
        #expect(shows.first?.id == show.id)
        #expect(shows.first?.version == show.version)

        #expect(operations.count == 1)
        #expect(operations.first?.entityID == show.id)

        #expect(
            operations.first?.entityType ==
            SyncEntityType.show.rawValue
        )

        #expect(
            operations.first?.operationType ==
            SyncOperationType.create.rawValue
        )

        #expect(
            operations.first?.version == show.version
        )

        #expect(
            operations.first?.status ==
            SyncOperationStatus.pending.rawValue
        )

        #expect(operations.first?.retryCount == 0)

        let payload = try #require(
            operations.first?.payload
        )

        let payloadData = try #require(
            payload.data(using: .utf8)
        )

        let dto = try JSONCoding.decoder.decode(
            ShowDTO.self,
            from: payloadData
        )

        #expect(dto.id == show.id)
        #expect(dto.tourID == show.tourID)
        #expect(dto.name == show.name)
        #expect(dto.venue == show.venue)
        #expect(dto.city == show.city)
        #expect(dto.version == show.version)
    }

    @Test
    func createShowThrowsDuplicateForExistingShow() async throws {

        let (repository, modelContext, syncScheduler) =
            try makeRepository()

        let show = makeShow()

        try await repository.createShow(show)

        await #expect(throws: RepositoryError.duplicate) {
            try await repository.createShow(show)
        }

        let showDescriptor = FetchDescriptor<ShowEntity>()
        let operationDescriptor = FetchDescriptor<SyncOperationEntity>()

        let shows = try modelContext.fetch(showDescriptor)
        let operations = try modelContext.fetch(operationDescriptor)

        #expect(shows.count == 1)
        #expect(operations.count == 1)

        #expect(syncScheduler.scheduleSyncCallCount == 1)
    }

    // MARK: - Update

    @Test
    func updateShowPersistsShowChangesAndSyncOperation() async throws {

        let (repository, modelContext, syncScheduler) =
            try makeRepository()

        let show = makeShow()

        try await repository.createShow(show)

        let updatedShow = Show(
            id: show.id,
            tourID: show.tourID,
            name: "Updated Show",
            venue: "Updated Venue",
            city: "Los Angeles",
            date: show.date,
            createdAt: show.createdAt,
            version: show.version
        )

        try await repository.updateShow(updatedShow)

        #expect(syncScheduler.scheduleSyncCallCount == 2)

        let showDescriptor = FetchDescriptor<ShowEntity>()
        let operationDescriptor = FetchDescriptor<SyncOperationEntity>()

        let shows = try modelContext.fetch(showDescriptor)
        let operations = try modelContext.fetch(operationDescriptor)

        #expect(shows.count == 1)
        #expect(shows.first?.name == "Updated Show")
        #expect(shows.first?.venue == "Updated Venue")
        #expect(shows.first?.city == "Los Angeles")

        #expect(shows.first?.version == 3)

        #expect(operations.count == 2)

        let updateOperation = operations.first {
            $0.operationType ==
            SyncOperationType.update.rawValue
        }

        #expect(updateOperation?.entityID == show.id)

        #expect(
            updateOperation?.entityType ==
            SyncEntityType.show.rawValue
        )

        #expect(
            updateOperation?.operationType ==
            SyncOperationType.update.rawValue
        )

        #expect(updateOperation?.version == show.version)

        #expect(
            updateOperation?.status ==
            SyncOperationStatus.pending.rawValue
        )

        #expect(updateOperation?.retryCount == 0)

        let payload = try #require(
            updateOperation?.payload
        )

        let payloadData = try #require(
            payload.data(using: .utf8)
        )

        let dto = try JSONCoding.decoder.decode(
            ShowDTO.self,
            from: payloadData
        )

        #expect(dto.id == updatedShow.id)
        #expect(dto.tourID == updatedShow.tourID)
        #expect(dto.name == updatedShow.name)
        #expect(dto.venue == updatedShow.venue)
        #expect(dto.city == updatedShow.city)
        #expect(dto.version == show.version + 1)
    }

    @Test
    func updateShowThrowsNotFoundForMissingShow() async throws {

        let (repository, modelContext, _) =
            try makeRepository()

        let show = makeShow()

        await #expect(throws: RepositoryError.notFound) {
            try await repository.updateShow(show)
        }

        let operationDescriptor = FetchDescriptor<SyncOperationEntity>()

        let operations = try modelContext.fetch(
            operationDescriptor
        )

        #expect(operations.isEmpty)
    }

    // MARK: - Delete

    @Test
    func deleteShowRemovesShowAndCreatesSyncOperation() async throws {

        let (repository, modelContext, syncScheduler) =
            try makeRepository()

        let show = makeShow()

        try await repository.createShow(show)
        try await repository.deleteShow(id: show.id)

        #expect(syncScheduler.scheduleSyncCallCount == 2)

        let showDescriptor = FetchDescriptor<ShowEntity>()
        let operationDescriptor = FetchDescriptor<SyncOperationEntity>()

        let shows = try modelContext.fetch(showDescriptor)
        let operations = try modelContext.fetch(operationDescriptor)

        #expect(shows.isEmpty)
        #expect(operations.count == 2)

        let deleteOperation = operations.first {
            $0.operationType ==
            SyncOperationType.delete.rawValue
        }

        #expect(deleteOperation?.entityID == show.id)

        #expect(
            deleteOperation?.entityType ==
            SyncEntityType.show.rawValue
        )

        #expect(
            deleteOperation?.operationType ==
            SyncOperationType.delete.rawValue
        )

        #expect(deleteOperation?.version == show.version)

        #expect(
            deleteOperation?.status ==
            SyncOperationStatus.pending.rawValue
        )

        #expect(deleteOperation?.retryCount == 0)
        #expect(deleteOperation?.payload == nil)
    }

    @Test
    func deleteShowThrowsNotFoundForMissingShow() async throws {

        let (repository, modelContext, _) =
            try makeRepository()

        let showID = UUID()

        await #expect(throws: RepositoryError.notFound) {
            try await repository.deleteShow(id: showID)
        }

        let operationDescriptor = FetchDescriptor<SyncOperationEntity>()

        let operations = try modelContext.fetch(
            operationDescriptor
        )

        #expect(operations.isEmpty)
    }

    // MARK: - Unresolved sync issues

    @Test(arguments: [SyncOperationStatus.conflict, SyncOperationStatus.failed])
    func updateShowIsRejectedWhileAnUnresolvedOperationExists(
        status: SyncOperationStatus
    ) async throws {

        let blocked = try await makeBlockedShow(status: status)
        let scheduleCount = blocked.syncScheduler.scheduleSyncCallCount

        await #expect(throws: RepositoryError.unresolvedSyncIssue) {
            try await blocked.repository.updateShow(
                edited(blocked.show, name: "Second Edit")
            )
        }

        let persisted = try await blocked.repository.fetchShow(
            id: blocked.show.id
        )

        #expect(persisted.name == "First Edit")
        #expect(persisted.version == blocked.show.version)

        let operations = try await blocked.syncOperationRepository
            .fetchOperations(forEntityID: blocked.show.id)

        // The blocking operation is kept exactly as it was, and nothing new
        // is queued.
        #expect(operations.count == 2)
        #expect(operations.contains(blocked.blockedOperation))
        #expect(blocked.syncScheduler.scheduleSyncCallCount == scheduleCount)
    }

    @Test(arguments: [SyncOperationStatus.conflict, SyncOperationStatus.failed])
    func deleteShowIsRejectedWhileAnUnresolvedOperationExists(
        status: SyncOperationStatus
    ) async throws {

        let blocked = try await makeBlockedShow(status: status)
        let scheduleCount = blocked.syncScheduler.scheduleSyncCallCount

        await #expect(throws: RepositoryError.unresolvedSyncIssue) {
            try await blocked.repository.deleteShow(id: blocked.show.id)
        }

        let persisted = try await blocked.repository.fetchShow(
            id: blocked.show.id
        )

        #expect(persisted.version == blocked.show.version)

        let operations = try await blocked.syncOperationRepository
            .fetchOperations(forEntityID: blocked.show.id)

        #expect(operations.count == 2)
        #expect(operations.contains(blocked.blockedOperation))
        #expect(blocked.syncScheduler.scheduleSyncCallCount == scheduleCount)
    }

    @Test
    func unresolvedOperationOnOneShowDoesNotBlockAnother() async throws {

        let blocked = try await makeBlockedShow(status: .conflict)

        let other = makeShow()
        let otherEntity = Show(id: UUID(), tourID: other.tourID, name: "Other", venue: other.venue, city: other.city, date: other.date, createdAt: other.createdAt, version: other.version)

        try await blocked.repository.createShow(otherEntity)
        try await blocked.repository.updateShow(
            edited(otherEntity, name: "Other Edit")
        )

        let persisted = try await blocked.repository.fetchShow(
            id: otherEntity.id
        )

        #expect(persisted.name == "Other Edit")
    }

    @Test
    func updateShowWorksAgainOnceTheBlockingOperationIsRemoved() async throws {

        let blocked = try await makeBlockedShow(status: .conflict)

        // Part B will remove operations through an explicit user action. The
        // test removes it directly only to show the guard is not sticky.
        try await blocked.syncOperationRepository.delete(
            blocked.blockedOperation
        )

        try await blocked.repository.updateShow(
            edited(blocked.show, name: "Second Edit")
        )

        let persisted = try await blocked.repository.fetchShow(
            id: blocked.show.id
        )

        #expect(persisted.name == "Second Edit")
        #expect(persisted.version == blocked.show.version + 1)
    }

    // MARK: - Helpers

    private func makeRepository() throws -> (
        repository: SyncTrackingShowRepository,
        modelContext: ModelContext,
        syncScheduler: MockSyncScheduler
    ) {

        let schema = Schema([
            ShowEntity.self,
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

        let showRepository = SwiftDataShowRepository(
            modelContext: modelContext
        )

        let syncOperationRepository =
            SwiftDataSyncOperationRepository(
                modelContext: modelContext
            )

        let syncScheduler = MockSyncScheduler()

        let repository = SyncTrackingShowRepository(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository,
            modelContext: modelContext,
            syncScheduler: syncScheduler
        )

        return (
            repository,
            modelContext,
            syncScheduler
        )
    }

    private func makeBlockedShow(
        status: SyncOperationStatus
    ) async throws -> (
        repository: SyncTrackingShowRepository,
        syncOperationRepository: SwiftDataSyncOperationRepository,
        syncScheduler: MockSyncScheduler,
        show: Show,
        blockedOperation: SyncOperation
    ) {

        let (repository, syncOperationRepository, syncScheduler) =
            try makeRepository()

        let created = makeShow()

        try await repository.createShow(created)
        try await repository.updateShow(
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

        let current = try await repository.fetchShow(id: created.id)

        return (
            repository,
            syncOperationRepository,
            syncScheduler,
            current,
            blockedOperation
        )
    }

    private func edited(_ show: Show, name: String) -> Show {

        Show(
            id: show.id,
            tourID: show.tourID,
            name: name,
            venue: show.venue,
            city: show.city,
            date: show.date,
            createdAt: show.createdAt,
            version: show.version
        )
    }

    private func makeShow() -> Show {

        Show(
            id: UUID(),
            tourID: UUID(),
            name: "Northbound",
            venue: "The Wiltern",
            city: "Los Angeles",
            date: Date(timeIntervalSince1970: 1_000),
            createdAt: Date(timeIntervalSince1970: 500),
            version: 2
        )
    }
}
