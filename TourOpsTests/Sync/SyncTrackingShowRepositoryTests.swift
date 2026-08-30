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
        let (repository, context) = try makeRepository()
        let show = makeShow()

        try await repository.createShow(show)

        let showDescriptor = FetchDescriptor<ShowEntity>()
        let operationDescriptor = FetchDescriptor<SyncOperationEntity>()

        let shows = try context.fetch(showDescriptor)
        let operations = try context.fetch(operationDescriptor)

        #expect(shows.count == 1)
        #expect(shows.first?.id == show.id)

        #expect(operations.count == 1)
        #expect(operations.first?.entityID == show.id)
        #expect(operations.first?.entityType == SyncEntityType.show.rawValue)
        #expect(
            operations.first?.operationType ==
            SyncOperationType.create.rawValue
        )
        #expect(
            operations.first?.status ==
            SyncOperationStatus.pending.rawValue
        )
    }

    @Test
    func createShowThrowsDuplicateForExistingShow() async throws {
        let (repository, context) = try makeRepository()
        let show = makeShow()

        try await repository.createShow(show)

        await #expect(throws: RepositoryError.duplicate) {
            try await repository.createShow(show)
        }

        let showDescriptor = FetchDescriptor<ShowEntity>()
        let operationDescriptor = FetchDescriptor<SyncOperationEntity>()

        let shows = try context.fetch(showDescriptor)
        let operations = try context.fetch(operationDescriptor)

        #expect(shows.count == 1)
        #expect(operations.count == 1)
    }

    // MARK: - Update

    @Test
    func updateShowPersistsShowChangesAndSyncOperation() async throws {
        let (repository, context) = try makeRepository()
        let show = makeShow()

        try await repository.createShow(show)

        let updatedShow = Show(
            id: show.id,
            tourID: show.tourID,
            name: "Updated Show",
            venue: "Updated Venue",
            city: "Los Angeles",
            date: show.date,
            createdAt: show.createdAt
        )

        try await repository.updateShow(updatedShow)

        let showDescriptor = FetchDescriptor<ShowEntity>()
        let operationDescriptor = FetchDescriptor<SyncOperationEntity>()

        let shows = try context.fetch(showDescriptor)
        let operations = try context.fetch(operationDescriptor)

        #expect(shows.count == 1)
        #expect(shows.first?.name == "Updated Show")
        #expect(shows.first?.venue == "Updated Venue")
        #expect(shows.first?.city == "Los Angeles")

        #expect(operations.count == 2)

        let updateOperation = operations.first {
            $0.operationType == SyncOperationType.update.rawValue
        }

        #expect(updateOperation?.entityID == show.id)
        #expect(updateOperation?.entityType == SyncEntityType.show.rawValue)
        #expect(
            updateOperation?.status ==
            SyncOperationStatus.pending.rawValue
        )
    }

    @Test
    func updateShowThrowsNotFoundForMissingShow() async throws {
        let (repository, context) = try makeRepository()
        let show = makeShow()

        await #expect(throws: RepositoryError.notFound) {
            try await repository.updateShow(show)
        }

        let operationDescriptor = FetchDescriptor<SyncOperationEntity>()
        let operations = try context.fetch(operationDescriptor)

        #expect(operations.isEmpty)
    }

    // MARK: - Delete

    @Test
    func deleteShowRemovesShowAndCreatesSyncOperation() async throws {
        let (repository, context) = try makeRepository()
        let show = makeShow()

        try await repository.createShow(show)

        try await repository.deleteShow(id: show.id)

        let showDescriptor = FetchDescriptor<ShowEntity>()
        let operationDescriptor = FetchDescriptor<SyncOperationEntity>()

        let shows = try context.fetch(showDescriptor)
        let operations = try context.fetch(operationDescriptor)

        #expect(shows.isEmpty)
        #expect(operations.count == 2)

        let deleteOperation = operations.first {
            $0.operationType == SyncOperationType.delete.rawValue
        }

        #expect(deleteOperation?.entityID == show.id)
        #expect(deleteOperation?.entityType == SyncEntityType.show.rawValue)
        #expect(
            deleteOperation?.status ==
            SyncOperationStatus.pending.rawValue
        )
    }

    @Test
    func deleteShowThrowsNotFoundForMissingShow() async throws {
        let (repository, context) = try makeRepository()
        let showID = UUID()

        await #expect(throws: RepositoryError.notFound) {
            try await repository.deleteShow(id: showID)
        }

        let operationDescriptor = FetchDescriptor<SyncOperationEntity>()
        let operations = try context.fetch(operationDescriptor)

        #expect(operations.isEmpty)
    }

    // MARK: - Helpers

    private func makeRepository() throws -> (
        repository: SyncTrackingShowRepository,
        context: ModelContext
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

        let context = ModelContext(container)

        let showRepository = SwiftDataShowRepository(
            modelContext: context
        )

        let syncOperationRepository = SwiftDataSyncOperationRepository(
            modelContext: context
        )

        let repository = SyncTrackingShowRepository(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository,
            modelContext: context
        )

        return (repository, context)
    }

    private func makeShow() -> Show {
        Show(
            id: UUID(),
            tourID: UUID(),
            name: "Northbound",
            venue: "The Wiltern",
            city: "Los Angeles",
            date: Date(timeIntervalSince1970: 1_000),
            createdAt: Date(timeIntervalSince1970: 500)
        
        )
    }
}
