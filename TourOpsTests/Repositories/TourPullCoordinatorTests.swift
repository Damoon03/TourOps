//
//  TourPullCoordinatorTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 7/13/1405 AP.
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct TourPullCoordinatorTests {

    @Test
    func pullToursFetchesAndReconcilesTours() async throws {

        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        let container = try ModelContainer(
            for: TourEntity.self,
            SyncOperationEntity.self,
            configurations: configuration
        )

        let tourRepository = SwiftDataTourRepository(
            modelContext: container.mainContext
        )

        let syncOperationRepository =
            MockSyncOperationRepository()

        let reconciler = TourReconciler(
            tourRepository: tourRepository,
            syncOperationRepository: syncOperationRepository
        )

        let expectedTours = [
            Tour(
                id: UUID(),
                teamID: UUID(),
                name: "Summer Tour",
                startDate: Date(),
                endDate: Date().addingTimeInterval(86_400),
                createdAt: Date(),
                version: 1
            )
        ]

        let pullService = MockTourPullService(
            tours: expectedTours
        )

        let coordinator = TourPullCoordinator(
            pullService: pullService,
            reconciler: reconciler
        )

        try await coordinator.pullTours()

        let fetchedTour = try await tourRepository.fetchTour(
            id: expectedTours[0].id
        )

        #expect(fetchedTour == expectedTours[0])
        #expect(pullService.fetchToursCallCount == 1)
    }
}

@MainActor
private final class MockTourPullService: TourPullServiceProtocol {

    let tours: [Tour]

    private(set) var fetchToursCallCount = 0

    init(tours: [Tour]) {
        self.tours = tours
    }

    func fetchTours() async throws -> [Tour] {
        fetchToursCallCount += 1
        return tours
    }
}

@MainActor
private final class MockSyncOperationRepository:
    SyncOperationRepositoryProtocol {

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
