//
//  SyncTrackingShowRepositoryTests.swift
//  TourOps
//
//  Created by Damoon saber on 9/6/1405 AP.
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
    let (repository, syncOperationRepository) = try makeRepository()

    let show = makeShow()

    try await repository.createShow(show)

    let persistedShow = try await repository.fetchShow(id: show.id)
    let operations = try await syncOperationRepository.fetchPendingOperations()

    #expect(persistedShow == show)
    #expect(operations.count == 1)

    let operation = try #require(operations.first)

    #expect(operation.entityID == show.id)
    #expect(operation.entityType == .show)
    #expect(operation.operationType == .create)
    #expect(operation.status == .pending)
    #expect(operation.retryCount == 0)
}

// MARK: - Update

@Test
func updateShowPersistsShowAndCreatesSyncOperation() async throws {
    let (repository, syncOperationRepository) = try makeRepository()

    let show = makeShow()

    try await repository.createShow(show)

    let updatedShow = Show(
        id: show.id,
        tourID: show.tourID,
        name: "Updated Show",
        venue: show.venue,
        city: show.city,
        date: show.date,
        createdAt: show.createdAt
    )

    try await repository.updateShow(updatedShow)

    let persistedShow = try await repository.fetchShow(id: show.id)
    let operations = try await syncOperationRepository.fetchPendingOperations()

    #expect(persistedShow == updatedShow)
    #expect(operations.count == 2)

    let updateOperations = operations.filter {
        $0.operationType == .update
    }

    #expect(updateOperations.count == 1)

    let operation = try #require(updateOperations.first)

    #expect(operation.entityID == show.id)
    #expect(operation.entityType == .show)
    #expect(operation.status == .pending)
    #expect(operation.retryCount == 0)
}

// MARK: - Delete

@Test
func deleteShowDeletesShowAndCreatesSyncOperation() async throws {
    let (repository, syncOperationRepository) = try makeRepository()

    let show = makeShow()

    try await repository.createShow(show)

    try await repository.deleteShow(id: show.id)

    await #expect(throws: RepositoryError.notFound) {
        try await repository.fetchShow(id: show.id)
    }

    let operations = try await syncOperationRepository.fetchPendingOperations()

    #expect(operations.count == 2)

    let deleteOperations = operations.filter {
        $0.operationType == .delete
    }

    #expect(deleteOperations.count == 1)

    let operation = try #require(deleteOperations.first)

    #expect(operation.entityID == show.id)
    #expect(operation.entityType == .show)
    #expect(operation.status == .pending)
    #expect(operation.retryCount == 0)
}

// MARK: - Helpers

private func makeRepository() throws -> (
    repository: SyncTrackingShowRepository,
    syncOperationRepository: SwiftDataSyncOperationRepository
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

    let syncOperationRepository = SwiftDataSyncOperationRepository(
        modelContext: modelContext
    )

    let repository = SyncTrackingShowRepository(
        showRepository: showRepository,
        syncOperationRepository: syncOperationRepository,
        modelContext: modelContext
    )

    return (
        repository,
        syncOperationRepository
    )
}

private func makeShow() -> Show {
    Show(
        id: UUID(),
        tourID: UUID(),
        name: "Test Show",
        venue: "Test Venue",
        city: "Baku",
        date: Date(timeIntervalSince1970: 1_000),
        createdAt: Date(timeIntervalSince1970: 900)
    )
}
}
