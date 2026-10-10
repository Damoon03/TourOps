//
//  TeamPullCoordinatorTests.swift
//  TourOpsTests
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct TeamPullCoordinatorTests {

    @Test
    func overlappingPullRequestsTriggerSequentialPulls() async throws {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        let container = try ModelContainer(
            for: TeamEntity.self,
            SyncOperationEntity.self,
            configurations: configuration
        )

        let teamRepository = SwiftDataTeamRepository(
            modelContext: container.mainContext
        )
        let syncOperationRepository = SwiftDataSyncOperationRepository(
            modelContext: container.mainContext
        )
        let reconciler = TeamReconciler(
            teamRepository: teamRepository,
            syncOperationRepository: syncOperationRepository
        )
        let service = SuspendingTeamPullService(teams: [])
        let coordinator = TeamPullCoordinator(
            pullService: service,
            reconciler: reconciler
        )

        let firstPull = Task {
            try await coordinator.pullTeams()
        }

        await service.waitUntilFirstFetchStarts()

        let secondPull = Task {
            try await coordinator.pullTeams()
        }

        await Task.yield()
        service.finishFirstFetch()

        try await firstPull.value
        try await secondPull.value

        #expect(service.fetchTeamsCallCount == 2)
    }
}

@MainActor
private final class SuspendingTeamPullService: TeamPullServiceProtocol {

    let teams: [Team]
    private(set) var fetchTeamsCallCount = 0

    private var firstFetchContinuation: CheckedContinuation<[Team], Error>?
    private var firstFetchStartedContinuation: CheckedContinuation<Void, Never>?

    init(teams: [Team]) {
        self.teams = teams
    }

    func fetchTeams() async throws -> [Team] {
        fetchTeamsCallCount += 1

        guard fetchTeamsCallCount == 1 else {
            return teams
        }

        firstFetchStartedContinuation?.resume()
        firstFetchStartedContinuation = nil

        return try await withCheckedThrowingContinuation { continuation in
            firstFetchContinuation = continuation
        }
    }

    func waitUntilFirstFetchStarts() async {
        if fetchTeamsCallCount > 0 {
            return
        }

        await withCheckedContinuation { continuation in
            firstFetchStartedContinuation = continuation
        }
    }

    func finishFirstFetch() {
        firstFetchContinuation?.resume(returning: teams)
        firstFetchContinuation = nil
    }
}
