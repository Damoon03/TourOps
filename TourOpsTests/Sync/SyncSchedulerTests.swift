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
}

// MARK: - Mock

@MainActor
private final class MockSyncEngine: SyncEngineProtocol {

    private(set) var syncCallCount = 0
    private(set) var isSyncing = false

    private var syncContinuation: CheckedContinuation<Void, Never>?
    private var syncStartedContinuation: CheckedContinuation<Void, Never>?

    private var syncCallCountContinuations: [
        (
            expectedCount: Int,
            continuation: CheckedContinuation<Void, Never>
        )
    ] = []

    func sync() async {
        syncCallCount += 1
        isSyncing = true

        syncStartedContinuation?.resume()
        syncStartedContinuation = nil

        resumeSyncCallCountWaiters()

        await withCheckedContinuation { continuation in
            syncContinuation = continuation
        }

        isSyncing = false
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

    func finishSync() {
        syncContinuation?.resume()
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
