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
    private var syncRequested = false

    init(
        syncEngine: SyncEngineProtocol
    ) {
        self.syncEngine = syncEngine
    }

    func scheduleSync() {
        syncRequested = true

        guard syncTask == nil else {
            return
        }

        startSyncTask()
    }
    
    func syncNow() async {
        if let syncTask {
            await syncTask.value
            return
        }

        syncRequested = true
        startSyncTask()

        await syncTask?.value
    }

    func cancelScheduledSync() {
        syncTask?.cancel()
        syncTask = nil
        syncRequested = false
    }

    private func startSyncTask() {
        guard syncTask == nil else {
            return
        }

        syncTask = Task {
            repeat {
                syncRequested = false

                await syncEngine.sync()

            } while syncRequested && !Task.isCancelled

            syncTask = nil
        }
    }
}
