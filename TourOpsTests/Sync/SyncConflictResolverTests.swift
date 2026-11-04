//
//  SyncConflictResolverTests.swift
//  TourOpsTests
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct SyncConflictResolverTests {

    // MARK: - Team: conflicts

    @Test
    func conflictedUpdateAppliesTheServerCopyAtAnEqualVersion() async throws {
        let env = try makeEnvironment()

        let local = makeTeam(name: "Local Band", version: 2)
        try await env.teamRepository.createTeam(local)

        let operation = makeOperation(
            entityID: local.id,
            type: .update,
            status: .conflict,
            version: 1
        )
        try await env.operationRepository.add(operation)

        // Equal versions do not prove equal content.
        env.pullService.teams = [
            makeTeam(id: local.id, name: "Server Band", version: 2)
        ]

        try await env.resolver.useServerVersion(for: makeIssue(operation))

        let fetched = try await env.teamRepository.fetchTeam(id: local.id)
        let remaining = try await env.operations(for: local.id)

        #expect(fetched.name == "Server Band")
        #expect(fetched.version == 2)
        #expect(remaining.isEmpty)
    }

    @Test
    func conflictedDeleteRestoresAnItemMissingLocally() async throws {
        let env = try makeEnvironment()

        let id = UUID()
        let operation = makeOperation(
            entityID: id,
            type: .delete,
            status: .conflict,
            version: 2
        )
        try await env.operationRepository.add(operation)

        env.pullService.teams = [
            makeTeam(id: id, name: "Server Band", version: 3)
        ]

        try await env.resolver.useServerVersion(for: makeIssue(operation))

        let restored = try await env.teamRepository.fetchTeam(id: id)
        let remaining = try await env.operations(for: id)

        #expect(restored.name == "Server Band")
        #expect(restored.version == 3)
        #expect(remaining.isEmpty)
    }

    @Test
    func conflictedDeleteAppliesTheServerCopyWhenAPullAlreadyRestoredIt() async throws {
        let env = try makeEnvironment()

        let restored = makeTeam(name: "Older Copy", version: 3)
        try await env.teamRepository.createTeam(restored)

        let operation = makeOperation(
            entityID: restored.id,
            type: .delete,
            status: .conflict,
            version: 2
        )
        try await env.operationRepository.add(operation)

        env.pullService.teams = [
            makeTeam(id: restored.id, name: "Server Band", version: 3)
        ]

        try await env.resolver.useServerVersion(for: makeIssue(operation))

        let fetched = try await env.teamRepository.fetchTeam(id: restored.id)
        let remaining = try await env.operations(for: restored.id)

        #expect(fetched.name == "Server Band")
        #expect(remaining.isEmpty)
    }

    @Test
    func conflictedDeleteWithTheServerRowAlsoGoneStaysDeleted() async throws {
        let env = try makeEnvironment()

        let id = UUID()
        let operation = makeOperation(
            entityID: id,
            type: .delete,
            status: .conflict,
            version: 2
        )
        try await env.operationRepository.add(operation)

        // The server has other rows, but not this one.
        env.pullService.teams = [makeTeam(name: "Someone Else", version: 1)]

        try await env.resolver.useServerVersion(for: makeIssue(operation))

        let remaining = try await env.operations(for: id)

        await #expect(throws: RepositoryError.notFound) {
            try await env.teamRepository.fetchTeam(id: id)
        }
        #expect(remaining.isEmpty)
    }

    @Test
    func conflictedUpdateWithTheServerRowGoneDeletesTheLocalCopy() async throws {
        let env = try makeEnvironment()

        let local = makeTeam(name: "Local Band", version: 2)
        try await env.teamRepository.createTeam(local)

        let operation = makeOperation(
            entityID: local.id,
            type: .update,
            status: .conflict,
            version: 1
        )
        try await env.operationRepository.add(operation)

        env.pullService.teams = [makeTeam(name: "Someone Else", version: 1)]

        try await env.resolver.useServerVersion(for: makeIssue(operation))

        let remaining = try await env.operations(for: local.id)

        await #expect(throws: RepositoryError.notFound) {
            try await env.teamRepository.fetchTeam(id: local.id)
        }
        #expect(remaining.isEmpty)
    }

    // MARK: - Team: unverifiable and failing servers

    @Test
    func anEmptyServerListChangesNothing() async throws {
        let env = try makeEnvironment()

        let local = makeTeam(name: "Local Band", version: 2)
        try await env.teamRepository.createTeam(local)

        let operation = makeOperation(
            entityID: local.id,
            type: .update,
            status: .conflict,
            version: 1
        )
        try await env.operationRepository.add(operation)

        env.pullService.teams = []

        await #expect(throws: SyncResolutionError.remoteStateUnverified) {
            try await env.resolver.useServerVersion(for: makeIssue(operation))
        }

        let fetched = try await env.teamRepository.fetchTeam(id: local.id)
        let remaining = try await env.operations(for: local.id)

        #expect(fetched.name == "Local Band")
        #expect(remaining == [operation])
    }

    @Test
    func aThrowingPullServiceChangesNothingAndTheErrorPropagates() async throws {
        let env = try makeEnvironment()

        let local = makeTeam(name: "Local Band", version: 2)
        try await env.teamRepository.createTeam(local)

        let operation = makeOperation(
            entityID: local.id,
            type: .update,
            status: .conflict,
            version: 1
        )
        try await env.operationRepository.add(operation)

        env.pullService.error = ResolverTestError.serverDown

        await #expect(throws: ResolverTestError.serverDown) {
            try await env.resolver.useServerVersion(for: makeIssue(operation))
        }

        let fetched = try await env.teamRepository.fetchTeam(id: local.id)
        let remaining = try await env.operations(for: local.id)

        #expect(fetched.name == "Local Band")
        #expect(remaining == [operation])
    }

    @Test
    func anIssueWithoutOperationsThrowsAndSkipsTheServer() async throws {
        let env = try makeEnvironment()

        let stale = makeIssue(
            makeOperation(
                entityID: UUID(),
                type: .update,
                status: .conflict,
                version: 1
            )
        )

        await #expect(throws: SyncResolutionError.noUnresolvedOperation) {
            try await env.resolver.useServerVersion(for: stale)
        }

        #expect(env.pullService.fetchCount == 0)
    }

    // MARK: - Team: running inside a sync cycle

    @Test
    func aResolutionIsRejectedAsBusyWhileACycleIsRunning() async throws {
        let env = try makeEnvironment()

        let local = makeTeam(name: "Local Band", version: 2)
        try await env.teamRepository.createTeam(local)

        let operation = makeOperation(
            entityID: local.id,
            type: .update,
            status: .conflict,
            version: 1
        )
        try await env.operationRepository.add(operation)

        env.pullService.teams = [
            makeTeam(id: local.id, name: "Server Band", version: 2)
        ]

        let blocker = CycleBlocker()
        let cycle = Task {
            await env.scheduler.runSyncCycle { await blocker.pull() }
        }

        await waitUntil { blocker.isBlocking }
        #expect(blocker.isBlocking)

        let issue = try makeIssue(operation)
        let attempt = Task {
            try await env.resolver.useServerVersion(for: issue)
        }

        // The attempt joins the running cycle, which only ends once the
        // blocker is released.
        await settle()
        blocker.release()

        await cycle.value
        let result = await attempt.result

        guard case .failure(let error) = result else {
            Issue.record("The resolution should not have run.")
            return
        }

        let fetched = try await env.teamRepository.fetchTeam(id: local.id)
        let remaining = try await env.operations(for: local.id)

        #expect(error as? SyncResolutionError == .busy)
        #expect(env.pullService.fetchCount == 0)
        #expect(fetched.name == "Local Band")
        #expect(remaining == [operation])
    }

    @Test
    func aCallerJoiningTheResolutionsCycleDoesNotRepeatTheWork() async throws {
        let env = try makeEnvironment()

        let local = makeTeam(name: "Local Band", version: 2)
        try await env.teamRepository.createTeam(local)

        let operation = makeOperation(
            entityID: local.id,
            type: .update,
            status: .conflict,
            version: 1
        )
        try await env.operationRepository.add(operation)

        env.pullService.teams = [
            makeTeam(id: local.id, name: "Server Band", version: 2)
        ]
        env.pullService.holdsFetches = true

        let issue = try makeIssue(operation)
        let resolution = Task {
            try await env.resolver.useServerVersion(for: issue)
        }

        await waitUntil { env.pullService.isHolding }
        #expect(env.pullService.isHolding)

        let joinerRan = Flag()
        let joiner = Task {
            await env.scheduler.runSyncCycle { joinerRan.value = true }
        }

        await settle()
        env.pullService.release()

        try await resolution.value
        await joiner.value

        let fetched = try await env.teamRepository.fetchTeam(id: local.id)
        let remaining = try await env.operations(for: local.id)

        // The follow-up cycle runs the resolution's closure again, which must
        // do nothing. The joiner's own closure is never run.
        #expect(env.pullService.fetchCount == 1)
        #expect(joinerRan.value == false)
        #expect(fetched.name == "Server Band")
        #expect(remaining.isEmpty)
    }

    // MARK: - Team: failed operations

    @Test
    func retryPutsFailedOperationsBackInTheQueue() async throws {
        let env = try makeEnvironment()

        let local = makeTeam(name: "Local Band", version: 2)
        try await env.teamRepository.createTeam(local)

        let operation = makeOperation(
            entityID: local.id,
            type: .update,
            status: .failed,
            version: 1,
            retryCount: 3
        )
        try await env.operationRepository.add(operation)

        try await env.resolver.retry(makeIssue(operation))

        await waitUntil { env.engine.syncCallCount >= 1 }

        let remaining = try await env.operations(for: local.id)
        let retried = try #require(remaining.first)

        #expect(remaining.count == 1)
        #expect(retried.id == operation.id)
        #expect(retried.status == .pending)
        #expect(retried.retryCount == 0)
        #expect(env.engine.syncCallCount >= 1)
    }

    @Test
    func discardOfAFailedUpdateAppliesTheServerCopy() async throws {
        let env = try makeEnvironment()

        let local = makeTeam(name: "Local Band", version: 2)
        try await env.teamRepository.createTeam(local)

        let operation = makeOperation(
            entityID: local.id,
            type: .update,
            status: .failed,
            version: 1
        )
        try await env.operationRepository.add(operation)

        env.pullService.teams = [
            makeTeam(id: local.id, name: "Server Band", version: 1)
        ]

        try await env.resolver.discard(makeIssue(operation))

        let fetched = try await env.teamRepository.fetchTeam(id: local.id)
        let remaining = try await env.operations(for: local.id)

        #expect(fetched.name == "Server Band")
        #expect(fetched.version == 1)
        #expect(remaining.isEmpty)
    }

    @Test
    func discardOfAFailedCreateRemovesTheItemWithoutAskingTheServer() async throws {
        let env = try makeEnvironment()

        let local = makeTeam(name: "Never Synced", version: 1)
        try await env.teamRepository.createTeam(local)

        let operation = makeOperation(
            entityID: local.id,
            type: .create,
            status: .failed,
            version: 1
        )
        try await env.operationRepository.add(operation)

        // A brand-new account legitimately has no rows, so an empty server
        // list must not block this.
        env.pullService.teams = []

        try await env.resolver.discard(makeIssue(operation))

        let remaining = try await env.operations(for: local.id)

        await #expect(throws: RepositoryError.notFound) {
            try await env.teamRepository.fetchTeam(id: local.id)
        }
        #expect(remaining.isEmpty)
        #expect(env.pullService.fetchCount == 0)
    }

    @Test
    func discardOfAFailedCreateIsRefusedWhileTheItemHasChildren() async throws {
        let env = try makeEnvironment()

        let team = makeTeam(name: "Never Synced", version: 1)
        try await env.teamRepository.createTeam(team)
        try await env.tourRepository.createTour(
            makeTour(teamID: team.id, name: "Child Tour", version: 1)
        )

        let operation = makeOperation(
            entityID: team.id,
            type: .create,
            status: .failed,
            version: 1
        )
        try await env.operationRepository.add(operation)

        await #expect(throws: SyncResolutionError.hasDependentItems) {
            try await env.resolver.discard(makeIssue(operation))
        }

        let fetched = try await env.teamRepository.fetchTeam(id: team.id)
        let remaining = try await env.operations(for: team.id)

        #expect(fetched.name == "Never Synced")
        #expect(remaining == [operation])
    }

    @Test
    func discardOfAFailedDeleteRestoresTheItem() async throws {
        let env = try makeEnvironment()

        let id = UUID()
        let operation = makeOperation(
            entityID: id,
            type: .delete,
            status: .failed,
            version: 2
        )
        try await env.operationRepository.add(operation)

        env.pullService.teams = [
            makeTeam(id: id, name: "Server Band", version: 2)
        ]

        try await env.resolver.discard(makeIssue(operation))

        let restored = try await env.teamRepository.fetchTeam(id: id)
        let remaining = try await env.operations(for: id)

        #expect(restored.name == "Server Band")
        #expect(remaining.isEmpty)
    }

    @Test
    func discardIsRefusedForAConflictOnlyIssue() async throws {
        let env = try makeEnvironment()

        let local = makeTeam(name: "Local Band", version: 2)
        try await env.teamRepository.createTeam(local)

        let operation = makeOperation(
            entityID: local.id,
            type: .update,
            status: .conflict,
            version: 1
        )
        try await env.operationRepository.add(operation)

        await #expect(throws: SyncResolutionError.noUnresolvedOperation) {
            try await env.resolver.discard(makeIssue(operation))
        }

        let remaining = try await env.operations(for: local.id)

        #expect(remaining == [operation])
        #expect(env.pullService.fetchCount == 0)
    }

    // MARK: - Tour

    @Test
    func conflictedTourUpdateAppliesTheServerCopyAtAnEqualVersion() async throws {
        let env = try makeEnvironment()

        let local = makeTour(name: "Local Tour", version: 2)
        try await env.tourRepository.createTour(local)

        let operation = makeOperation(
            entityID: local.id,
            entityType: .tour,
            type: .update,
            status: .conflict,
            version: 1
        )
        try await env.operationRepository.add(operation)

        env.pullService.tours = [
            makeTour(id: local.id, teamID: local.teamID, name: "Server Tour", version: 2)
        ]

        try await env.resolver.useServerVersion(for: makeIssue(operation))

        let fetched = try await env.tourRepository.fetchTour(id: local.id)
        let remaining = try await env.operations(for: local.id)

        #expect(fetched.name == "Server Tour")
        #expect(remaining.isEmpty)
    }

    @Test
    func conflictedTourDeleteRestoresTheTour() async throws {
        let env = try makeEnvironment()

        let id = UUID()
        let operation = makeOperation(
            entityID: id,
            entityType: .tour,
            type: .delete,
            status: .conflict,
            version: 2
        )
        try await env.operationRepository.add(operation)

        env.pullService.tours = [
            makeTour(id: id, name: "Server Tour", version: 3)
        ]

        try await env.resolver.useServerVersion(for: makeIssue(operation))

        let restored = try await env.tourRepository.fetchTour(id: id)
        let remaining = try await env.operations(for: id)

        #expect(restored.name == "Server Tour")
        #expect(remaining.isEmpty)
    }

    @Test
    func discardOfAFailedTourCreateIsRefusedWhileShowsExist() async throws {
        let env = try makeEnvironment()

        let tour = makeTour(name: "Never Synced", version: 1)
        try await env.tourRepository.createTour(tour)
        try await env.showRepository.createShow(
            makeShow(tourID: tour.id, name: "Child Show", version: 1)
        )

        let operation = makeOperation(
            entityID: tour.id,
            entityType: .tour,
            type: .create,
            status: .failed,
            version: 1
        )
        try await env.operationRepository.add(operation)

        await #expect(throws: SyncResolutionError.hasDependentItems) {
            try await env.resolver.discard(makeIssue(operation))
        }

        let fetched = try await env.tourRepository.fetchTour(id: tour.id)

        #expect(fetched.name == "Never Synced")
    }

    // MARK: - Show

    @Test
    func conflictedShowUpdateAppliesTheServerCopyAtAnEqualVersion() async throws {
        let env = try makeEnvironment()

        let local = makeShow(name: "Local Show", version: 2)
        try await env.showRepository.createShow(local)

        let operation = makeOperation(
            entityID: local.id,
            entityType: .show,
            type: .update,
            status: .conflict,
            version: 1
        )
        try await env.operationRepository.add(operation)

        env.pullService.shows = [
            makeShow(id: local.id, tourID: local.tourID, name: "Server Show", version: 2)
        ]

        try await env.resolver.useServerVersion(for: makeIssue(operation))

        let fetched = try await env.showRepository.fetchShow(id: local.id)
        let remaining = try await env.operations(for: local.id)

        #expect(fetched.name == "Server Show")
        #expect(remaining.isEmpty)
    }

    @Test
    func conflictedShowDeleteRestoresTheShow() async throws {
        let env = try makeEnvironment()

        let id = UUID()
        let operation = makeOperation(
            entityID: id,
            entityType: .show,
            type: .delete,
            status: .conflict,
            version: 2
        )
        try await env.operationRepository.add(operation)

        env.pullService.shows = [
            makeShow(id: id, name: "Server Show", version: 3)
        ]

        try await env.resolver.useServerVersion(for: makeIssue(operation))

        let restored = try await env.showRepository.fetchShow(id: id)
        let remaining = try await env.operations(for: id)

        #expect(restored.name == "Server Show")
        #expect(remaining.isEmpty)
    }

    @Test
    func discardOfAFailedShowCreateRemovesTheShowWithoutAskingTheServer() async throws {
        let env = try makeEnvironment()

        let local = makeShow(name: "Never Synced", version: 1)
        try await env.showRepository.createShow(local)

        let operation = makeOperation(
            entityID: local.id,
            entityType: .show,
            type: .create,
            status: .failed,
            version: 1
        )
        try await env.operationRepository.add(operation)

        try await env.resolver.discard(makeIssue(operation))

        let remaining = try await env.operations(for: local.id)

        await #expect(throws: RepositoryError.notFound) {
            try await env.showRepository.fetchShow(id: local.id)
        }
        #expect(remaining.isEmpty)
        #expect(env.pullService.fetchCount == 0)
    }

    // MARK: - Helpers

    private func makeEnvironment() throws -> ResolverEnvironment {
        let schema = Schema([
            TeamEntity.self,
            TourEntity.self,
            ShowEntity.self,
            SyncOperationEntity.self
        ])

        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let modelContext = ModelContext(container)

        let teamRepository = SwiftDataTeamRepository(modelContext: modelContext)
        let tourRepository = SwiftDataTourRepository(modelContext: modelContext)
        let showRepository = SwiftDataShowRepository(modelContext: modelContext)

        let operationRepository = SwiftDataSyncOperationRepository(
            modelContext: modelContext
        )

        let engine = ImmediateSyncEngine()
        let scheduler = SyncScheduler(syncEngine: engine)
        let pullService = StubPullService()

        let resolver = SyncConflictResolver(
            scheduler: scheduler,
            teamRepository: teamRepository,
            tourRepository: tourRepository,
            showRepository: showRepository,
            teamPullService: pullService,
            tourPullService: pullService,
            showPullService: pullService,
            modelContext: modelContext
        )

        return ResolverEnvironment(
            container: container,
            teamRepository: teamRepository,
            tourRepository: tourRepository,
            showRepository: showRepository,
            operationRepository: operationRepository,
            engine: engine,
            scheduler: scheduler,
            pullService: pullService,
            resolver: resolver
        )
    }

    private func makeIssue(_ operation: SyncOperation) throws -> SyncIssue {
        try #require(SyncIssue.issues(from: [operation]).first)
    }

    private func makeOperation(
        entityID: UUID,
        entityType: SyncEntityType = .team,
        type: SyncOperationType,
        status: SyncOperationStatus,
        version: Int,
        retryCount: Int = 0
    ) -> SyncOperation {
        SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: entityType,
            operationType: type,
            payload: nil,
            version: version,
            createdAt: Date(timeIntervalSince1970: 1_000),
            status: status,
            retryCount: retryCount
        )
    }

    private func makeTeam(
        id: UUID = UUID(),
        name: String,
        version: Int
    ) -> Team {
        Team(
            id: id,
            name: name,
            genre: "Rock",
            country: "Azerbaijan",
            city: "Baku",
            createdAt: Date(timeIntervalSince1970: 900),
            version: version
        )
    }

    private func makeTour(
        id: UUID = UUID(),
        teamID: UUID = UUID(),
        name: String,
        version: Int
    ) -> Tour {
        Tour(
            id: id,
            teamID: teamID,
            name: name,
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000),
            createdAt: Date(timeIntervalSince1970: 900),
            version: version
        )
    }

    private func makeShow(
        id: UUID = UUID(),
        tourID: UUID = UUID(),
        name: String,
        version: Int
    ) -> Show {
        Show(
            id: id,
            tourID: tourID,
            name: name,
            venue: "The Wiltern",
            city: "Los Angeles",
            date: Date(timeIntervalSince1970: 1_000),
            createdAt: Date(timeIntervalSince1970: 500),
            version: version
        )
    }

    /// Lets tasks that were already enqueued on the main actor run up to
    /// their next suspension point.
    private func settle() async {
        for _ in 0..<10 {
            await Task.yield()
        }
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<500 {
            if condition() {
                return
            }

            await Task.yield()
        }
    }
}

// MARK: - Environment

@MainActor
private struct ResolverEnvironment {
    let container: ModelContainer
    let teamRepository: SwiftDataTeamRepository
    let tourRepository: SwiftDataTourRepository
    let showRepository: SwiftDataShowRepository
    let operationRepository: SwiftDataSyncOperationRepository
    let engine: ImmediateSyncEngine
    let scheduler: SyncScheduler
    let pullService: StubPullService
    let resolver: SyncConflictResolver

    func operations(for entityID: UUID) async throws -> [SyncOperation] {
        try await operationRepository.fetchOperations(forEntityID: entityID)
    }
}

// MARK: - Fakes

private enum ResolverTestError: Error, Equatable {
    case serverDown
}

@MainActor
private final class Flag {
    var value = false
}

@MainActor
private final class ImmediateSyncEngine: SyncEngineProtocol {

    private(set) var syncCallCount = 0

    func sync() async -> SyncRunResult {
        syncCallCount += 1
        return .noWork
    }
}

/// Stands in for a cycle that is already running: it blocks the cycle's pull
/// step until released, and does not block again after that.
@MainActor
private final class CycleBlocker {

    private(set) var isBlocking = false

    private var isReleased = false
    private var continuation: CheckedContinuation<Void, Never>?

    func pull() async {
        guard !isReleased else {
            return
        }

        isBlocking = true

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }

        isBlocking = false
    }

    func release() {
        isReleased = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class StubPullService:
    TeamPullServiceProtocol,
    TourPullServiceProtocol,
    ShowPullServiceProtocol
{

    var teams: [Team] = []
    var tours: [Tour] = []
    var shows: [Show] = []
    var error: Error?
    var holdsFetches = false

    private(set) var fetchCount = 0

    private var held: [CheckedContinuation<Void, Never>] = []

    var isHolding: Bool {
        !held.isEmpty
    }

    func fetchTeams() async throws -> [Team] {
        try await begin()
        return teams
    }

    func fetchTours() async throws -> [Tour] {
        try await begin()
        return tours
    }

    func fetchShows() async throws -> [Show] {
        try await begin()
        return shows
    }

    func release() {
        holdsFetches = false

        let continuations = held
        held = []

        for continuation in continuations {
            continuation.resume()
        }
    }

    private func begin() async throws {
        fetchCount += 1

        if holdsFetches {
            await withCheckedContinuation { continuation in
                held.append(continuation)
            }
        }

        if let error {
            throw error
        }
    }
}
