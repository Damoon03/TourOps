//
//  MockSyncScheduler.swift
//  TourOpsTests
//
//  Created by Damoon saber on 1/7/1405 AP.
//

import Foundation
@testable import TourOps

@MainActor
final class MockSyncScheduler: SyncSchedulerProtocol {

    var scheduleSyncCallCount = 0
    var syncNowCallCount = 0

    var syncNowResult: SyncRunResult = .noWork

    func scheduleSync() {
        scheduleSyncCallCount += 1
    }

    func syncNow() async -> SyncRunResult {
        syncNowCallCount += 1
        return syncNowResult
    }

    func cancelScheduledSync() {}
}
