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
    let (repository, syncOperationRepository) = try makeRepository()

    let tour = makeTour()

    try await repository.createTour(tour)

    let persistedTour = try await repository.fetchTour(id: tour.id)
    let operations = try await syncOperationRepository.fetchPendingOperations()

    #expect(persistedTour == tour)
    #expect(operations.count == 1)

    let operation = try #require(operations.first)

    #expect(operation.entityID == tour.id)
    #expect(operation.entityType == .tour)
    #expect(operation.operationType == .create)
    #expect(operation.status == .pending)
    #expect(operation.retryCount == 0)
}

// MARK: - Update

@Test
func updateTourPersistsTourAndCreatesSyncOperation() async throws {
    let (repository, syncOperationRepository) = try makeRepository()

    let tour = makeTour()

    try await repository.createTour(tour)

    let updatedTour = Tour(
        id: tour.id,
        teamID: tour.teamID,
        name: "Updated Tour",
        startDate: tour.startDate,
        endDate: tour.endDate,
        createdAt: tour.createdAt
    )

    try await repository.updateTour(updatedTour)

    let persistedTour = try await repository.fetchTour(id: tour.id)
    let operations = try await syncOperationRepository.fetchPendingOperations()

    #expect(persistedTour == updatedTour)
    #expect(operations.count == 2)

    let updateOperations = operations.filter {
        $0.operationType == .update
    }

    #expect(updateOperations.count == 1)

    let operation = try #require(updateOperations.first)

    #expect(operation.entityID == tour.id)
    #expect(operation.entityType == .tour)
    #expect(operation.status == .pending)
    #expect(operation.retryCount == 0)
}

// MARK: - Delete

@Test
func deleteTourDeletesTourAndCreatesSyncOperation() async throws {
    let (repository, syncOperationRepository) = try makeRepository()

    let tour = makeTour()

    try await repository.createTour(tour)

    try await repository.deleteTour(id: tour.id)

    await #expect(throws: RepositoryError.notFound) {
        try await repository.fetchTour(id: tour.id)
    }

    let operations = try await syncOperationRepository.fetchPendingOperations()

    #expect(operations.count == 2)

    let deleteOperations = operations.filter {
        $0.operationType == .delete
    }

    #expect(deleteOperations.count == 1)

    let operation = try #require(deleteOperations.first)

    #expect(operation.entityID == tour.id)
    #expect(operation.entityType == .tour)
    #expect(operation.operationType == .delete)
    #expect(operation.status == .pending)
    #expect(operation.retryCount == 0)
}

// MARK: - Helpers

private func makeRepository() throws -> (
    repository: SyncTrackingTourRepository,
    syncOperationRepository: SwiftDataSyncOperationRepository
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

    let syncOperationRepository = SwiftDataSyncOperationRepository(
        modelContext: modelContext
    )

    let repository = SyncTrackingTourRepository(
        tourRepository: tourRepository,
        syncOperationRepository: syncOperationRepository,
        modelContext: modelContext
    )

    return (
        repository,
        syncOperationRepository
    )
}

private func makeTour() -> Tour {
    Tour(
        id: UUID(),
        teamID: UUID(),
        name: "Test Tour",
        startDate: Date(timeIntervalSince1970: 1_000),
        endDate: Date(timeIntervalSince1970: 2_000),
        createdAt: Date(timeIntervalSince1970: 900)
    )
}
}
