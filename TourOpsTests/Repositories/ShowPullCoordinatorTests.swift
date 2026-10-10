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

    @Test
    func overlappingPullRequestsTriggerSequentialPulls() async throws {
        let service = SuspendingShowPullService(shows: [])
        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )
        let coordinator = ShowPullCoordinator(
            pullService: service,
            reconciler: reconciler
        )

        let firstPull = Task {
            try await coordinator.pullShows()
        }

        await service.waitUntilFirstFetchStarts()

        let secondPull = Task {
            try await coordinator.pullShows()
        }

        await Task.yield()
        service.finishFirstFetch()

        try await firstPull.value
        try await secondPull.value

        #expect(service.fetchShowsCallCount == 2)
    }
}

@MainActor
private final class SuspendingShowPullService: ShowPullServiceProtocol {

    let shows: [Show]
    private(set) var fetchShowsCallCount = 0

    private var firstFetchContinuation: CheckedContinuation<[Show], Error>?
    private var firstFetchStartedContinuation: CheckedContinuation<Void, Never>?

    init(shows: [Show]) {
        self.shows = shows
    }

    func fetchShows() async throws -> [Show] {
        fetchShowsCallCount += 1

        guard fetchShowsCallCount == 1 else {
            return shows
        }

        firstFetchStartedContinuation?.resume()
        firstFetchStartedContinuation = nil

        return try await withCheckedThrowingContinuation { continuation in
            firstFetchContinuation = continuation
        }
    }

    func waitUntilFirstFetchStarts() async {
        if fetchShowsCallCount > 0 {
            return
        }

        await withCheckedContinuation { continuation in
            firstFetchStartedContinuation = continuation
        }
    }

    func finishFirstFetch() {
        firstFetchContinuation?.resume(returning: shows)
        firstFetchContinuation = nil
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
