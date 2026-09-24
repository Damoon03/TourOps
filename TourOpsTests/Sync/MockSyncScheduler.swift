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

    func scheduleSync() {
        scheduleSyncCallCount += 1
    }

    func cancelScheduledSync() {
    }
}
