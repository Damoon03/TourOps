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

    private var cycleTask: Task<Void, Never>?
    private var cycleRerunRequested = false
    private var isPullActive = false

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

        // While a Pull is fetching and reconciling, a Push must not start:
        // it could delete queue operations that the reconciler relies on
        // to protect local records. The request stays recorded and is
        // honoured as soon as the Pull releases the scheduler.
        guard syncTask == nil, !isPullActive else {
            return
        }

        startSyncTask()
    }

    /// Runs a Push and returns its result. If a Pull is currently active, the
    /// Push is deferred until the Pull finishes and this method returns
    /// `.noWork` once the enclosing cycle has completed.
    ///
    /// Must not be called from inside the `pull` closure of `runSyncCycle`.
    func syncNow() async -> SyncRunResult {
        if isPullActive {
            syncRequested = true
            await cycleTask?.value
            return .noWork
        }

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

    /// Runs one complete Push, then Pull cycle and does not let any other
    /// Push or Pull interleave with it.
    ///
    /// - A cycle requested while another is in flight is coalesced into a
    ///   single follow-up cycle that starts after the current one finishes.
    ///   Callers join the in-flight cycle and return when it has completed.
    /// - `scheduleSync()` calls made while `pull` is running are recorded and
    ///   pushed once `pull` returns. Local writes and queued operations are
    ///   never delayed, only the network Push is.
    /// - Coordination is released on every exit path, including
    ///   cancellation.
    ///
    /// `pull` handles its own errors. It must not call `syncNow()`.
    func runSyncCycle(
        pull: @escaping @MainActor () async -> Void
    ) async {
        if let cycleTask {
            cycleRerunRequested = true
            await cycleTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            await self.executeSyncCycle(pull: pull)
        }

        cycleTask = task

        await task.value
    }

    func cancelScheduledSync() {
        syncTask?.cancel()
        syncTask = nil
        syncRequested = false

        cycleTask?.cancel()
        cycleRerunRequested = false
    }

    private func executeSyncCycle(
        pull: @MainActor () async -> Void
    ) async {
        defer {
            isPullActive = false
            cycleRerunRequested = false
            cycleTask = nil
        }

        repeat {
            if Task.isCancelled {
                return
            }

            // Push phase: send everything queued so far and wait for any
            // independently scheduled Push to finish.
            syncRequested = true
            startSyncTask()
            await waitForSyncTask()

            if Task.isCancelled {
                return
            }

            // A request made before the Pull starts is covered by this
            // Pull, so only later requests need a follow-up cycle.
            cycleRerunRequested = false

            // No suspension point exists between the end of the wait above
            // and this assignment, so no Push can start in between.
            isPullActive = true
            await pull()
            isPullActive = false

            let willRerun = cycleRerunRequested && !Task.isCancelled

            // Changes queued while the Pull ran are pushed now. When a
            // follow-up cycle is coming, its Push phase covers them.
            if syncRequested && !willRerun {
                startSyncTask()
                await waitForSyncTask()
            }
        } while cycleRerunRequested && !Task.isCancelled
    }

    private func waitForSyncTask() async {
        while let task = syncTask {
            _ = await task.value
        }
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
