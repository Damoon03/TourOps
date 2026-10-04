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

    private var syncTask: Task<Void, Never>?

    init(
        syncEngine: SyncEngineProtocol
    ) {
        self.syncEngine = syncEngine
    }

    func scheduleSync() {
        guard syncTask == nil else {
            return
        }

        syncTask = Task {
            await syncEngine.sync()
            syncTask = nil
        }
    }

    func syncNow() async {
        if let syncTask {
            await syncTask.value
            return
        }

        let task = Task {
            await syncEngine.sync()
        }

        syncTask = task

        await task.value

        if syncTask != nil {
            syncTask = nil
        }
    }

    func cancelScheduledSync() {
        syncTask?.cancel()
        syncTask = nil
    }
}
