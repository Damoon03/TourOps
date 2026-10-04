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

        let scheduler = SyncScheduler(
            syncEngine: engine
        )

        scheduler.scheduleSync()

        await engine.waitUntilSyncStarts()

        #expect(
            engine.syncCallCount == 1
        )

        engine.finishSync()

        try await Task.sleep(
            nanoseconds: 10_000_000
        )
    }

    @Test
    func scheduleSyncDoesNotStartDuplicateSync() async throws {
        let engine = MockSyncEngine()

        let scheduler = SyncScheduler(
            syncEngine: engine
        )

        scheduler.scheduleSync()
        scheduler.scheduleSync()

        await engine.waitUntilSyncStarts()

        #expect(
            engine.syncCallCount == 1
        )

        engine.finishSync()

        try await Task.sleep(
            nanoseconds: 10_000_000
        )

        #expect(
            engine.syncCallCount == 1
        )
    }

    @Test
    func cancelScheduledSyncDoesNotTriggerSync() async throws {
        let engine = MockSyncEngine()

        let scheduler = SyncScheduler(
            syncEngine: engine
        )

        scheduler.cancelScheduledSync()

        try await Task.sleep(
            nanoseconds: 10_000_000
        )

        #expect(
            engine.syncCallCount == 0
        )
    }

    @Test
    func syncNowWaitsForSyncToFinish() async throws {
        let engine = MockSyncEngine()

        let scheduler = SyncScheduler(
            syncEngine: engine
        )

        var syncNowFinished = false

        let task = Task {
            await scheduler.syncNow()
            syncNowFinished = true
        }

        await engine.waitUntilSyncStarts()

        #expect(
            engine.syncCallCount == 1
        )

        #expect(
            syncNowFinished == false
        )

        engine.finishSync()

        await task.value

        #expect(
            syncNowFinished == true
        )
    }

    @Test
    func syncNowWaitsForExistingScheduledSync() async throws {
        let engine = MockSyncEngine()

        let scheduler = SyncScheduler(
            syncEngine: engine
        )

        scheduler.scheduleSync()

        await engine.waitUntilSyncStarts()

        var syncNowFinished = false

        let task = Task {
            await scheduler.syncNow()
            syncNowFinished = true
        }

        await Task.yield()

        #expect(
            engine.syncCallCount == 1
        )

        #expect(
            syncNowFinished == false
        )

        engine.finishSync()

        await task.value

        #expect(
            engine.syncCallCount == 1
        )

        #expect(
            syncNowFinished == true
        )
    }

    @Test
    func schedulerCanPerformAnotherSyncAfterPreviousSyncCompletes() async throws {
        let engine = MockSyncEngine()

        let scheduler = SyncScheduler(
            syncEngine: engine
        )

        let firstTask = Task {
            await scheduler.syncNow()
        }

        await engine.waitUntilSyncStarts()

        #expect(
            engine.syncCallCount == 1
        )

        engine.finishSync()

        await firstTask.value

        let secondTask = Task {
            await scheduler.syncNow()
        }

        await engine.waitUntilSyncStarts()

        #expect(
            engine.syncCallCount == 2
        )

        engine.finishSync()

        await secondTask.value
    }
}

// MARK: - Mock

@MainActor
private final class MockSyncEngine: SyncEngineProtocol {

    var syncCallCount = 0

    private var syncContinuation: CheckedContinuation<Void, Never>?
    private var syncStartedContinuation: CheckedContinuation<Void, Never>?

    private(set) var isSyncing = false

    func sync() async {
        syncCallCount += 1
        isSyncing = true

        syncStartedContinuation?.resume()
        syncStartedContinuation = nil

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

    func finishSync() {
        syncContinuation?.resume()
        syncContinuation = nil
    }
}
