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
    private let onChangeQueued: (() -> Void)?
    private let onRunFinished: ((SyncRunResult) -> Void)?

    private var syncTask: Task<SyncRunResult, Never>?
    private var syncRequested = false

    /// - Parameters:
    ///   - onChangeQueued: Called each time `scheduleSync()` is requested,
    ///     which happens when a local change has been queued.
    ///   - onRunFinished: Called once per scheduler run with the aggregated
    ///     result, for both `scheduleSync()` and `syncNow()`. Callers that
    ///     join a run already in flight do not cause a second report.
    init(
        syncEngine: SyncEngineProtocol,
        onChangeQueued: (() -> Void)? = nil,
        onRunFinished: ((SyncRunResult) -> Void)? = nil
    ) {
        self.syncEngine = syncEngine
        self.onChangeQueued = onChangeQueued
        self.onRunFinished = onRunFinished
    }

    func scheduleSync() {
        onChangeQueued?()
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
            onRunFinished?(finalResult)
            return finalResult
        }
    }
}

