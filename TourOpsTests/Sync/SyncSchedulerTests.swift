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

        try await Task.sleep(
            nanoseconds: 100_000_000
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
            nanoseconds: 100_000_000
        )

        #expect(
            engine.syncCallCount == 0
        )
    }
}


// MARK: - Mock

@MainActor
private final class MockSyncEngine: SyncEngineProtocol {

    var syncCallCount = 0


    func sync() async {

        syncCallCount += 1
    }
}

