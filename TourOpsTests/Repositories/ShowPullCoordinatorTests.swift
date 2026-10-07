//
//  ShowPullCoordinatorTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 7/14/1405 AP.
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct ShowPullCoordinatorTests {

    private let container: ModelContainer

    init() throws {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        self.container = try ModelContainer(
            for:
                TeamEntity.self,
                TourEntity.self,
                ShowEntity.self,
                SyncOperationEntity.self,
            configurations: configuration
        )
    }

    private var showRepository: SwiftDataShowRepository {
        SwiftDataShowRepository(
            modelContext: container.mainContext
        )
    }

    private var syncOperationRepository: SwiftDataSyncOperationRepository {
        SwiftDataSyncOperationRepository(
            modelContext: container.mainContext
        )
    }

    @Test
    func pullShowsReconcilesShowsFromService() async throws {

        let expectedShow = Show(
            id: UUID(),
            tourID: UUID(),
            name: "Paris Show",
            venue: "Olympia",
            city: "Paris",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        let service = MockShowPullService(
            shows: [expectedShow]
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        let coordinator = ShowPullCoordinator(
            pullService: service,
            reconciler: reconciler
        )

        try await coordinator.pullShows()

        let shows = try await showRepository.fetchShows()

        #expect(shows.count == 1)
        #expect(shows[0] == expectedShow)
    }
}

@MainActor
private final class MockShowPullService: ShowPullServiceProtocol {

    let shows: [Show]

    init(shows: [Show]) {
        self.shows = shows
    }

    func fetchShows() async throws -> [Show] {
        shows
    }
}
