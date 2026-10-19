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

    private var syncTask: Task<SyncRunResult, Never>?
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

    func syncNow() async -> SyncRunResult {
        if let syncTask {
            return await syncTask.value
        }

        syncRequested = true
        startSyncTask()

        guard let syncTask else {
            return .failure
        }

        return await syncTask.value
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

        syncTask = Task { @MainActor [weak self] in
            guard let self else {
                return .cancelled
            }

            var finalResult: SyncRunResult = .noWork

            repeat {
                syncRequested = false

                if Task.isCancelled {
                    finalResult = .cancelled
                    break
                }

                let result = await syncEngine.sync()

                switch result {
                case .failure:
                    finalResult = .failure

                case .cancelled:
                    finalResult = .cancelled

                case .success:
                    if finalResult != .failure &&
                        finalResult != .cancelled {
                        finalResult = .success
                    }

                case .noWork:
                    break
                }

            } while syncRequested && !Task.isCancelled

            if Task.isCancelled {
                finalResult = .cancelled
            }

            syncTask = nil
            return finalResult
        }
    }
}

