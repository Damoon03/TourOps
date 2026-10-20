//
//  SyncSchedulerTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

@MainActor
struct SyncSchedulerTests {

    @Test
    func scheduleSyncTriggersSyncEngine() async throws {
        let engine = MockSyncEngine()
        let scheduler = SyncScheduler(syncEngine: engine)

        scheduler.scheduleSync()

        await engine.waitUntilSyncStarts()

        #expect(engine.syncCallCount == 1)

        engine.finishSync()

        try await Task.sleep(nanoseconds: 10_000_000)
    }

    @Test
    func scheduleSyncDoesNotStartDuplicateSync() async throws {
        let engine = MockSyncEngine()
        let scheduler = SyncScheduler(syncEngine: engine)

        scheduler.scheduleSync()
        scheduler.scheduleSync()

        await engine.waitUntilSyncStarts()

        #expect(engine.syncCallCount == 1)

        engine.finishSync()

        try await Task.sleep(nanoseconds: 10_000_000)

        #expect(engine.syncCallCount == 1)
    }

    @Test
    func scheduleSyncDuringActiveSyncTriggersAnotherSync() async {
        let engine = MockSyncEngine()
        let scheduler = SyncScheduler(syncEngine: engine)

        let initialTask = Task {
            await scheduler.syncNow()
        }

        await engine.waitUntilSyncStarts()

        #expect(engine.syncCallCount == 1)

        scheduler.scheduleSync()

        engine.finishSync()

        await engine.waitUntilSyncCallCount(2)

        #expect(engine.syncCallCount == 2)

        engine.finishSync()

        await initialTask.value
    }

    @Test
    func cancelScheduledSyncDoesNotTriggerSync() async throws {
        let engine = MockSyncEngine()
        let scheduler = SyncScheduler(syncEngine: engine)

        scheduler.cancelScheduledSync()

        try await Task.sleep(nanoseconds: 10_000_000)

        #expect(engine.syncCallCount == 0)
    }

    @Test
    func syncNowWaitsForSyncToFinish() async {
        let engine = MockSyncEngine()
        let scheduler = SyncScheduler(syncEngine: engine)

        var syncNowFinished = false

        let task = Task {
            await scheduler.syncNow()
            syncNowFinished = true
        }

        await engine.waitUntilSyncStarts()

        #expect(engine.syncCallCount == 1)
        #expect(syncNowFinished == false)

        engine.finishSync()

        await task.value

        #expect(syncNowFinished == true)
    }

    @Test
    func syncNowWaitsForExistingScheduledSync() async {
        let engine = MockSyncEngine()
        let scheduler = SyncScheduler(syncEngine: engine)

        scheduler.scheduleSync()
        await engine.waitUntilSyncStarts()

        var syncNowFinished = false

        let task = Task {
            await scheduler.syncNow()
            syncNowFinished = true
        }

        await Task.yield()

        #expect(engine.syncCallCount == 1)
        #expect(syncNowFinished == false)

        engine.finishSync()
        await task.value

        #expect(engine.syncCallCount == 1)
        #expect(syncNowFinished == true)
    }

    @Test
    func schedulerCanPerformAnotherSyncAfterPreviousSyncCompletes() async {
        let engine = MockSyncEngine()
        let scheduler = SyncScheduler(syncEngine: engine)

        let firstTask = Task {
            await scheduler.syncNow()
        }

        await engine.waitUntilSyncStarts()

        #expect(engine.syncCallCount == 1)

        engine.finishSync()

        await firstTask.value

        let secondTask = Task {
            await scheduler.syncNow()
        }

        await engine.waitUntilSyncCallCount(2)

        #expect(engine.syncCallCount == 2)

        engine.finishSync()

        await secondTask.value
    }

    // MARK: - Result Reporting

    @Test
    func scheduledSyncReportsItsResult() async {
        let engine = MockSyncEngine()
        let recorder = RunRecorder()
        let scheduler = makeScheduler(engine: engine, recorder: recorder)

        scheduler.scheduleSync()
        await engine.waitUntilSyncStarts()

        engine.finishSync(with: .success)
        await recorder.waitForResults(1)

        #expect(recorder.results == [.success])
        #expect(recorder.changeQueuedCount == 1)
    }

    @Test
    func directSyncNowReportsItsResultOnce() async {
        let engine = MockSyncEngine()
        let recorder = RunRecorder()
        let scheduler = makeScheduler(engine: engine, recorder: recorder)

        let task = Task {
            await scheduler.syncNow()
        }

        await engine.waitUntilSyncStarts()
        engine.finishSync(with: .failure)

        let result = await task.value

        #expect(result == .failure)
        #expect(recorder.results == [.failure])
        #expect(recorder.changeQueuedCount == 0)
    }

    @Test
    func joiningAnInFlightRunDoesNotReportTwice() async {
        let engine = MockSyncEngine()
        let recorder = RunRecorder()
        let scheduler = makeScheduler(engine: engine, recorder: recorder)

        scheduler.scheduleSync()
        await engine.waitUntilSyncStarts()

        let joined = Task {
            await scheduler.syncNow()
        }

        await Task.yield()

        engine.finishSync(with: .success)

        let result = await joined.value

        #expect(result == .success)
        #expect(engine.syncCallCount == 1)
        #expect(recorder.results == [.success])
    }

    @Test
    func coalescedRunsKeepFailureOverLaterSuccess() async {
        let result = await runCoalesced(first: .failure, second: .success)

        #expect(result.returned == .failure)
        #expect(result.reported == [.failure])
    }

    @Test
    func coalescedRunsKeepSuccessOverLaterNoWork() async {
        let result = await runCoalesced(first: .success, second: .noWork)

        #expect(result.returned == .success)
        #expect(result.reported == [.success])
    }

    @Test
    func coalescedRunsReportSuccessWhenOnlyLaterRunPushes() async {
        let result = await runCoalesced(first: .noWork, second: .success)

        #expect(result.returned == .success)
        #expect(result.reported == [.success])
    }

    @Test
    func coalescedRunsReportNoWorkWhenNeitherRunHasWork() async {
        let result = await runCoalesced(first: .noWork, second: .noWork)

        #expect(result.returned == .noWork)
        #expect(result.reported == [.noWork])
    }

    @Test
    func coalescedRunsKeepCancellationOverLaterSuccess() async {
        let result = await runCoalesced(first: .cancelled, second: .success)

        #expect(result.returned == .cancelled)
        #expect(result.reported == [.cancelled])
    }

    // MARK: - Helpers

    private func makeScheduler(
        engine: MockSyncEngine,
        recorder: RunRecorder
    ) -> SyncScheduler {
        SyncScheduler(
            syncEngine: engine,
            onChangeQueued: {
                recorder.changeQueuedCount += 1
            },
            onRunFinished: { result in
                recorder.record(result)
            }
        )
    }

    /// Runs one scheduler run whose engine is invoked twice because a second
    /// sync was requested while the first was in flight.
    private func runCoalesced(
        first: SyncRunResult,
        second: SyncRunResult
    ) async -> (returned: SyncRunResult, reported: [SyncRunResult]) {
        let engine = MockSyncEngine()
        let recorder = RunRecorder()
        let scheduler = makeScheduler(engine: engine, recorder: recorder)

        let task = Task {
            await scheduler.syncNow()
        }

        await engine.waitUntilSyncStarts()

        scheduler.scheduleSync()

        engine.finishSync(with: first)
        await engine.waitUntilSyncCallCount(2)

        engine.finishSync(with: second)

        let returned = await task.value

        return (returned, recorder.results)
    }
}

// MARK: - Recorder

@MainActor
private final class RunRecorder {

    private(set) var results: [SyncRunResult] = []
    var changeQueuedCount = 0

    private var waiter: (
        expectedCount: Int,
        continuation: CheckedContinuation<Void, Never>
    )?

    func record(_ result: SyncRunResult) {
        results.append(result)

        if let waiter, results.count >= waiter.expectedCount {
            self.waiter = nil
            waiter.continuation.resume()
        }
    }

    func waitForResults(_ expectedCount: Int) async {
        if results.count >= expectedCount {
            return
        }

        await withCheckedContinuation { continuation in
            waiter = (expectedCount, continuation)
        }
    }
}

// MARK: - Mock

@MainActor
private final class MockSyncEngine: SyncEngineProtocol {

    private(set) var syncCallCount = 0
    private(set) var isSyncing = false

    private var syncContinuation:
        CheckedContinuation<SyncRunResult, Never>?
    
    private var syncStartedContinuation: CheckedContinuation<Void, Never>?

    private var syncCallCountContinuations: [
        (
            expectedCount: Int,
            continuation: CheckedContinuation<Void, Never>
        )
    ] = []

    func sync() async -> SyncRunResult {
        syncCallCount += 1
        isSyncing = true

        syncStartedContinuation?.resume()
        syncStartedContinuation = nil

        resumeSyncCallCountWaiters()

        let result = await withCheckedContinuation {
            (continuation: CheckedContinuation<SyncRunResult, Never>) in
            syncContinuation = continuation
        }

        isSyncing = false
        return result
    }

    func waitUntilSyncStarts() async {
        if isSyncing {
            return
        }

        await withCheckedContinuation { continuation in
            syncStartedContinuation = continuation
        }
    }

    func waitUntilSyncCallCount(_ expectedCount: Int) async {
        if syncCallCount >= expectedCount {
            return
        }

        await withCheckedContinuation { continuation in
            syncCallCountContinuations.append(
                (
                    expectedCount: expectedCount,
                    continuation: continuation
                )
            )
        }
    }

    func finishSync(
        with result: SyncRunResult = .success
    ) {
        syncContinuation?.resume(returning: result)
        syncContinuation = nil
    }

    private func resumeSyncCallCountWaiters() {
        let readyWaiters = syncCallCountContinuations.filter {
            syncCallCount >= $0.expectedCount
        }

        syncCallCountContinuations.removeAll {
            syncCallCount >= $0.expectedCount
        }

        for waiter in readyWaiters {
            waiter.continuation.resume()
        }
    }
}
