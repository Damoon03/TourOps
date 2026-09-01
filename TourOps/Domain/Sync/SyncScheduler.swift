//
//  SyncScheduler.swift
//  TourOps
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation

@MainActor
final class SyncScheduler: SyncSchedulerProtocol {

    private let syncEngine: SyncEngineProtocol

    init(
        syncEngine: SyncEngineProtocol
    ) {
        self.syncEngine = syncEngine
    }


    func scheduleSync() {

        Task {
            await syncEngine.sync()
        }
    }


    func cancelScheduledSync() {

        // Background scheduling will be added later.
        // Current implementation has no active scheduled task.
    }
}
