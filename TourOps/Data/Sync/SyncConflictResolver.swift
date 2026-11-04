//
//  SyncConflictResolver.swift
//  TourOps
//
//  Resolves conflict and failed operations when the user asks. Actions that
//  read the server or change entity data run as the "pull" step of one
//  scheduler cycle, so no push or pull can interleave with them.
//

import Foundation
import SwiftData

@MainActor
final class SyncConflictResolver: SyncConflictResolving {

    private let scheduler: SyncScheduler
    private let teamRepository: SwiftDataTeamRepository
    private let tourRepository: SwiftDataTourRepository
    private let showRepository: SwiftDataShowRepository
    private let teamPullService: TeamPullServiceProtocol
    private let tourPullService: TourPullServiceProtocol
    private let showPullService: ShowPullServiceProtocol
    private let modelContext: ModelContext

    init(
        scheduler: SyncScheduler,
        teamRepository: SwiftDataTeamRepository,
        tourRepository: SwiftDataTourRepository,
        showRepository: SwiftDataShowRepository,
        teamPullService: TeamPullServiceProtocol,
        tourPullService: TourPullServiceProtocol,
        showPullService: ShowPullServiceProtocol,
        modelContext: ModelContext
    ) {
        self.scheduler = scheduler
        self.teamRepository = teamRepository
        self.tourRepository = tourRepository
        self.showRepository = showRepository
        self.teamPullService = teamPullService
        self.tourPullService = tourPullService
        self.showPullService = showPullService
        self.modelContext = modelContext
    }

    // MARK: - SyncConflictResolving

    func useServerVersion(for issue: SyncIssue) async throws {
        try await runExclusively { [self] in
            try await replaceWithServerState(
                for: issue,
                resolving: [.conflict, .failed]
            )
        }
    }

    /// Only changes local operation state, so it does not need the cycle: a
    /// failed operation is never fetched for sending, and the engine picks the
    /// retried operation up on its next run.
    func retry(_ issue: SyncIssue) async throws {
        let operations = try unresolvedOperations(
            for: issue,
            resolving: [.failed]
        )

        for operation in operations
        where operation.status == SyncOperationStatus.failed.rawValue {
            operation.status = SyncOperationStatus.pending.rawValue
            operation.retryCount = 0
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }

        scheduler.scheduleSync()
    }

    func discard(_ issue: SyncIssue) async throws {
        try await runExclusively { [self] in
            let operations = try unresolvedOperations(
                for: issue,
                resolving: [.failed]
            )

            let isUnsyncedCreate = operations.contains {
                $0.operationType == SyncOperationType.create.rawValue
            }

            if isUnsyncedCreate {
                try discardUnsyncedCreate(issue)
            } else {
                try await replaceWithServerState(
                    for: issue,
                    resolving: [.failed]
                )
            }
        }
    }

    // MARK: - Running inside a sync cycle

    /// What the closure given to `runSyncCycle` leaves behind. That closure
    /// cannot throw, so errors are stored here and rethrown afterwards.
    private final class Run {
        var didRun = false
        var failure: Error?
    }

    /// `runSyncCycle` ignores the closure of a caller that joins a cycle which
    /// is already running, and it may call the first caller's closure again
    /// for a follow-up cycle. So the closure does its work at most once, and
    /// `didRun` tells whether it ran at all.
    private func runExclusively(
        _ work: @escaping @MainActor () async throws -> Void
    ) async throws {
        let run = Run()

        await scheduler.runSyncCycle {
            guard !run.didRun else {
                return
            }

            run.didRun = true

            do {
                try await work()
            } catch {
                run.failure = error
            }
        }

        guard run.didRun else {
            throw SyncResolutionError.busy
        }

        if let failure = run.failure {
            throw failure
        }
    }

    // MARK: - Use the server's state

    private func replaceWithServerState(
        for issue: SyncIssue,
        resolving statuses: Set<SyncOperationStatus>
    ) async throws {
        // A stale issue should not cost a network round trip.
        _ = try unresolvedOperations(for: issue, resolving: statuses)

        let entityID = issue.entityID

        // Every `await` happens in this switch's fetch. Everything after it
        // stages and saves synchronously, so nothing else can run in between
        // and `rollback()` in `commit` cannot discard unrelated changes.
        switch issue.entityType {
        case .team:
            let remote = try await teamPullService.fetchTeams()

            guard !remote.isEmpty else {
                throw SyncResolutionError.remoteStateUnverified
            }

            let match = remote.first { $0.id == entityID }

            try commit(issue, resolving: statuses) {
                try stageTeam(match, id: entityID)
            }

        case .tour:
            let remote = try await tourPullService.fetchTours()

            guard !remote.isEmpty else {
                throw SyncResolutionError.remoteStateUnverified
            }

            let match = remote.first { $0.id == entityID }

            try commit(issue, resolving: statuses) {
                try stageTour(match, id: entityID)
            }

        case .show:
            let remote = try await showPullService.fetchShows()

            guard !remote.isEmpty else {
                throw SyncResolutionError.remoteStateUnverified
            }

            let match = remote.first { $0.id == entityID }

            try commit(issue, resolving: statuses) {
                try stageShow(match, id: entityID)
            }
        }
    }

    private func stageTeam(_ remote: Team?, id: UUID) throws {
        let exists = try modelContext.fetchCount(
            FetchDescriptor<TeamEntity>(
                predicate: #Predicate { $0.id == id }
            )
        ) > 0

        switch (remote, exists) {
        case (let remote?, true):
            try teamRepository.stageApplyRemoteTeam(remote)
        case (let remote?, false):
            try teamRepository.stageCreateTeam(remote)
        case (nil, true):
            try teamRepository.stageDeleteTeam(id: id)
        case (nil, false):
            break
        }
    }

    private func stageTour(_ remote: Tour?, id: UUID) throws {
        let exists = try modelContext.fetchCount(
            FetchDescriptor<TourEntity>(
                predicate: #Predicate { $0.id == id }
            )
        ) > 0

        switch (remote, exists) {
        case (let remote?, true):
            try tourRepository.stageApplyRemoteTour(remote)
        case (let remote?, false):
            try tourRepository.stageCreateTour(remote)
        case (nil, true):
            try tourRepository.stageDeleteTour(id: id)
        case (nil, false):
            break
        }
    }

    private func stageShow(_ remote: Show?, id: UUID) throws {
        let exists = try modelContext.fetchCount(
            FetchDescriptor<ShowEntity>(
                predicate: #Predicate { $0.id == id }
            )
        ) > 0

        switch (remote, exists) {
        case (let remote?, true):
            try showRepository.stageApplyRemoteShow(remote)
        case (let remote?, false):
            try showRepository.stageCreateShow(remote)
        case (nil, true):
            try showRepository.stageDeleteShow(id: id)
        case (nil, false):
            break
        }
    }

    // MARK: - Discard a create that never reached the server

    /// Local only: the server was never told about this item, so no server
    /// state is needed. If the create did reach it, the next pull restores it.
    private func discardUnsyncedCreate(_ issue: SyncIssue) throws {
        // No await between this check and the commit.
        try ensureNoDependentItems(for: issue)

        let entityID = issue.entityID

        try commit(issue, resolving: [.failed]) {
            switch issue.entityType {
            case .team:
                try stageTeam(nil, id: entityID)
            case .tour:
                try stageTour(nil, id: entityID)
            case .show:
                try stageShow(nil, id: entityID)
            }
        }
    }

    /// Children in any state count, including ones that are themselves
    /// waiting to sync, because their own sync cannot succeed without the
    /// parent.
    private func ensureNoDependentItems(for issue: SyncIssue) throws {
        let id = issue.entityID
        let count: Int

        switch issue.entityType {
        case .team:
            count = try modelContext.fetchCount(
                FetchDescriptor<TourEntity>(
                    predicate: #Predicate { $0.teamID == id }
                )
            )
        case .tour:
            count = try modelContext.fetchCount(
                FetchDescriptor<ShowEntity>(
                    predicate: #Predicate { $0.tourID == id }
                )
            )
        case .show:
            count = 0
        }

        if count > 0 {
            throw SyncResolutionError.hasDependentItems
        }
    }

    // MARK: - Persisting

    /// Stages the change, removes every operation of the entity and saves, in
    /// one synchronous run.
    ///
    /// There is no `await` between staging and the save, and nothing is staged
    /// before this call, so `rollback()` after a failure discards only what
    /// this method staged and never another caller's pending changes.
    private func commit(
        _ issue: SyncIssue,
        resolving statuses: Set<SyncOperationStatus>,
        stage: () throws -> Void
    ) throws {
        // Read again: the queue may have changed while the server was queried.
        let operations = try unresolvedOperations(
            for: issue,
            resolving: statuses
        )

        do {
            try stage()

            for operation in operations {
                modelContext.delete(operation)
            }

            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// All operations of the entity, provided at least one has one of the
    /// given statuses.
    private func unresolvedOperations(
        for issue: SyncIssue,
        resolving statuses: Set<SyncOperationStatus>
    ) throws -> [SyncOperationEntity] {
        let entityID = issue.entityID

        let operations = try modelContext.fetch(
            FetchDescriptor<SyncOperationEntity>(
                predicate: #Predicate { $0.entityID == entityID }
            )
        )

        let rawStatuses = Set(statuses.map(\.rawValue))

        guard operations.contains(where: { rawStatuses.contains($0.status) }) else {
            throw SyncResolutionError.noUnresolvedOperation
        }

        return operations
    }
}
