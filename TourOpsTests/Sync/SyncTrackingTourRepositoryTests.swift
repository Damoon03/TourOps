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
        #expect(operation.version == tour.version)
        #expect(operation.status == .pending)
        #expect(operation.retryCount == 0)

        let payload = try #require(operation.payload)

        let payloadData = try #require(
            payload.data(using: .utf8)
        )

        let dto = try JSONDecoder().decode(
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
        let (repository, syncOperationRepository) = try makeRepository()
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

        let persistedTour = try await repository.fetchTour(id: tour.id)
        let operations = try await syncOperationRepository.fetchPendingOperations()

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

        // The operation is based on version 2.
        #expect(operation.version == tour.version)

        #expect(operation.status == .pending)
        #expect(operation.retryCount == 0)

        let payload = try #require(operation.payload)

        let payloadData = try #require(
            payload.data(using: .utf8)
        )

        let dto = try JSONDecoder().decode(
            TourDTO.self,
            from: payloadData
        )

        #expect(dto.id == updatedTour.id)
        #expect(dto.teamID == updatedTour.teamID)
        #expect(dto.name == updatedTour.name)
        #expect(dto.startDate == updatedTour.startDate)
        #expect(dto.endDate == updatedTour.endDate)
        #expect(dto.createdAt == updatedTour.createdAt)
        #expect(dto.version == updatedTour.version)
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

        // Delete is based on the version that existed before deletion.
        #expect(operation.version == tour.version)

        #expect(operation.status == .pending)
        #expect(operation.retryCount == 0)
        #expect(operation.payload == nil)
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
            createdAt: Date(timeIntervalSince1970: 900),
            version: 2
        )
    }
}
