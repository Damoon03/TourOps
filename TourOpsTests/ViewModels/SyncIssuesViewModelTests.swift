//
//  SyncIssuesViewModelTests.swift
//  TourOpsTests
//

import Foundation
import Testing
@testable import TourOps

@MainActor
struct SyncIssuesViewModelTests {

    // MARK: - Refresh signal

    @Test
    func useServerVersionBumpsTheRefreshSignalOnSuccess() async {
        let (model, resolver, signal) = makeModel()

        let completed = await model.useServerVersion(for: makeIssue())

        #expect(completed)
        #expect(resolver.useServerVersionCallCount == 1)
        #expect(signal.generation == 1)
    }

    @Test
    func discardBumpsTheRefreshSignalOnSuccess() async {
        let (model, resolver, signal) = makeModel()

        let completed = await model.discard(makeIssue())

        #expect(completed)
        #expect(resolver.discardCallCount == 1)
        #expect(signal.generation == 1)
    }

    @Test
    func retryDoesNotBumpTheRefreshSignal() async {
        let (model, resolver, signal) = makeModel()

        let completed = await model.retry(makeIssue())

        #expect(completed)
        #expect(resolver.retryCallCount == 1)
        #expect(signal.generation == 0)
    }

    @Test
    func aFailedActionDoesNotBumpTheRefreshSignal() async {
        let (model, resolver, signal) = makeModel()
        resolver.error = SyncResolutionError.remoteStateUnverified

        let completed = await model.useServerVersion(for: makeIssue())

        #expect(completed == false)
        #expect(signal.generation == 0)
    }

    // MARK: - Errors

    @Test
    func aFailedActionShowsTheErrorMessage() async {
        let (model, resolver, _) = makeModel()
        resolver.error = SyncResolutionError.busy

        _ = await model.discard(makeIssue())

        #expect(model.errorMessage == "Sync is running. Try again in a moment.")
    }

    @Test
    func theNextActionClearsThePreviousError() async {
        let (model, resolver, _) = makeModel()
        resolver.error = SyncResolutionError.busy

        _ = await model.retry(makeIssue())
        #expect(model.errorMessage != nil)

        resolver.error = nil
        _ = await model.retry(makeIssue())

        #expect(model.errorMessage == nil)
    }

    @Test
    func dismissErrorClearsTheMessage() async {
        let (model, resolver, _) = makeModel()
        resolver.error = SyncResolutionError.hasDependentItems

        _ = await model.discard(makeIssue())
        model.dismissError()

        #expect(model.errorMessage == nil)
    }

    @Test
    func aCancelledActionIsNotShownAsAnError() async {
        let (model, resolver, signal) = makeModel()
        resolver.error = CancellationError()

        let completed = await model.useServerVersion(for: makeIssue())

        #expect(completed == false)
        #expect(model.errorMessage == nil)
        #expect(signal.generation == 0)
    }

    // MARK: - One action at a time

    @Test
    func anotherActionIsIgnoredWhileOneIsRunning() async {
        let (model, resolver, signal) = makeModel()
        resolver.holdsActions = true

        let first = Task {
            await model.useServerVersion(for: makeIssue())
        }

        for _ in 0..<200 where !resolver.isHolding {
            await Task.yield()
        }

        #expect(model.isWorking)

        let second = await model.discard(makeIssue())

        resolver.release()
        let firstCompleted = await first.value

        #expect(second == false)
        #expect(firstCompleted)
        #expect(resolver.discardCallCount == 0)
        #expect(resolver.useServerVersionCallCount == 1)
        #expect(signal.generation == 1)
        #expect(model.isWorking == false)
    }

    // MARK: - Wording

    @Test
    func titleNamesTheItemOrSaysItWasDeleted() {
        let issue = makeIssue(type: .update)

        #expect(issue.title(name: "Northbound") == "Team: Northbound")
        #expect(issue.title(name: nil) == "Deleted team")
    }

    @Test
    func conflictExplanationDependsOnTheOperation() {
        #expect(
            makeIssue(type: .update).explanation
                == "You changed this offline, and it was also changed on the server."
        )
        #expect(
            makeIssue(type: .delete).explanation
                == "You deleted this, but it was changed on the server."
        )
    }

    @Test
    func failedExplanationIsGeneric() {
        let issue = makeIssue(type: .update, kind: .failed)

        #expect(issue.explanation == "This change couldn’t be sent.")
    }

    @Test
    func discardMessageDependsOnWhetherTheItemWasEverSent() {
        let create = makeIssue(type: .create, kind: .failed)
        let update = makeIssue(type: .update, kind: .failed)

        #expect(
            create.discardMessage(name: "Northbound")
                == "“Northbound” was never saved to the server. It will be removed from this device."
        )
        #expect(
            update.discardMessage(name: "Northbound")
                == "Your change to “Northbound” will be removed and the server’s version restored."
        )
    }

    @Test
    func useServerVersionMessageWorksWithoutAName() {
        let issue = makeIssue(type: .delete)

        #expect(
            issue.useServerVersionMessage(name: nil)
                == "Your change to this team will be replaced by the server’s version. This can’t be undone."
        )
    }

    // MARK: - Helpers

    private func makeModel() -> (
        SyncIssuesViewModel,
        StubResolver,
        DataRefreshSignal
    ) {
        let resolver = StubResolver()
        let signal = DataRefreshSignal()

        let model = SyncIssuesViewModel(
            resolver: resolver,
            refreshSignal: signal
        )

        return (model, resolver, signal)
    }

    private func makeIssue(
        type: SyncOperationType = .update,
        kind: SyncIssue.Kind = .conflict
    ) -> SyncIssue {
        SyncIssue(
            entityID: UUID(),
            entityType: .team,
            operationTypes: [type],
            kind: kind,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
    }
}

// MARK: - Stub

@MainActor
private final class StubResolver: SyncConflictResolving {

    var error: Error?
    var holdsActions = false

    private(set) var useServerVersionCallCount = 0
    private(set) var retryCallCount = 0
    private(set) var discardCallCount = 0

    private var held: [CheckedContinuation<Void, Never>] = []

    var isHolding: Bool {
        !held.isEmpty
    }

    func useServerVersion(for issue: SyncIssue) async throws {
        useServerVersionCallCount += 1
        try await finish()
    }

    func retry(_ issue: SyncIssue) async throws {
        retryCallCount += 1
        try await finish()
    }

    func discard(_ issue: SyncIssue) async throws {
        discardCallCount += 1
        try await finish()
    }

    func release() {
        holdsActions = false

        let continuations = held
        held = []

        for continuation in continuations {
            continuation.resume()
        }
    }

    private func finish() async throws {
        if holdsActions {
            await withCheckedContinuation { continuation in
                held.append(continuation)
            }
        }

        if let error {
            throw error
        }
    }
}
