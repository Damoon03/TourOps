//
//  SyncStatusModelTests.swift
//  TourOpsTests
//

import Foundation
import Testing
@testable import TourOps

@MainActor
struct SyncStatusModelTests {

    // MARK: - Success state

    @Test
    func successResultShowsTransientSuccess() async {
        let (model, _) = makeModel()

        model.recordRunResult(.success)

        #expect(model.showsSynced)
        #expect(model.presentation(unsyncedCount: 0) == .synced)
    }

    @Test
    func resultsOtherThanSuccessDoNotShowSuccess() {
        for result in [SyncRunResult.noWork, .failure, .cancelled] {
            let (model, _) = makeModel()

            model.recordRunResult(result)

            #expect(model.showsSynced == false)
            #expect(model.presentation(unsyncedCount: 0) == .hidden)
        }
    }

    @Test
    func failureClearsEarlierSuccess() {
        let (model, _) = makeModel()

        model.recordRunResult(.success)
        model.recordRunResult(.failure)

        #expect(model.showsSynced == false)
    }

    @Test
    func cancellationClearsEarlierSuccess() {
        let (model, _) = makeModel()

        model.recordRunResult(.success)
        model.recordRunResult(.cancelled)

        #expect(model.showsSynced == false)
    }

    @Test
    func noWorkKeepsEarlierSuccessVisible() {
        let (model, _) = makeModel()

        model.recordRunResult(.success)
        model.recordRunResult(.noWork)

        #expect(model.showsSynced)
    }

    @Test
    func queuedChangeClearsSuccessImmediately() {
        let (model, _) = makeModel()

        model.recordRunResult(.success)
        model.changeQueued()

        #expect(model.showsSynced == false)
    }

    @Test
    func goingOfflineClearsSuccess() {
        let (model, _) = makeModel()

        model.recordRunResult(.success)
        model.setOnline(false)

        #expect(model.showsSynced == false)
        #expect(model.isOffline)
    }

    @Test
    func successReportedWhileOfflineIsNotShown() {
        let (model, _) = makeModel()

        model.setOnline(false)
        model.recordRunResult(.success)

        #expect(model.showsSynced == false)
    }

    // MARK: - Expiry

    @Test
    func successExpiresAfterConfiguredDuration() async {
        let (model, sleeper) = makeModel()

        model.recordRunResult(.success)
        await sleeper.waitUntilSleeping()

        #expect(sleeper.requestedDurations == [.seconds(2)])
        #expect(model.showsSynced)

        sleeper.elapse()
        await model.successExpiryTask?.value

        #expect(model.showsSynced == false)
        #expect(model.presentation(unsyncedCount: 0) == .hidden)
    }

    @Test
    func staleExpiryDoesNotHideNewerSuccess() async {
        let (model, sleeper) = makeModel()

        model.recordRunResult(.success)
        await sleeper.waitUntilSleeping()

        let staleTask = model.successExpiryTask

        model.changeQueued()
        model.recordRunResult(.success)
        await sleeper.waitUntilSleeping(count: 2)

        let newerTask = model.successExpiryTask

        // The first timer fires, but it belongs to a cleared success.
        sleeper.elapseOldest()
        await staleTask?.value

        #expect(model.showsSynced)

        sleeper.elapse()
        await newerTask?.value

        #expect(model.showsSynced == false)
    }

    // MARK: - Presentation

    @Test
    func offlineIsShownWithEmptyQueue() {
        let (model, _) = makeModel()

        model.setOnline(false)

        #expect(model.presentation(unsyncedCount: 0) == .offline(unsyncedCount: 0))
    }

    @Test
    func offlineShowsQueuedCount() {
        let (model, _) = makeModel()

        model.setOnline(false)

        #expect(model.presentation(unsyncedCount: 3) == .offline(unsyncedCount: 3))
    }

    @Test
    func onlineShowsQueuedCount() {
        let (model, _) = makeModel()

        #expect(model.presentation(unsyncedCount: 2) == .unsynced(count: 2))
    }

    @Test
    func onlineWithEmptyQueueAndNoSuccessIsHidden() {
        let (model, _) = makeModel()

        #expect(model.presentation(unsyncedCount: 0) == .hidden)
    }

    @Test
    func remainingQueueTakesPriorityOverSuccess() {
        let (model, _) = makeModel()

        model.recordRunResult(.success)

        #expect(model.presentation(unsyncedCount: 1) == .unsynced(count: 1))
    }

    // MARK: - Connectivity stream

    @Test
    func connectivityUpdatesDriveOfflineState() async {
        let monitor = MockConnectivityMonitor()
        let (model, _) = makeModel(monitor: monitor)

        monitor.send(false)
        monitor.finish()

        await model.observeConnectivity()

        #expect(model.isOffline)
    }

    @Test
    func connectivityRecoveryClearsOfflineState() async {
        let monitor = MockConnectivityMonitor()
        let (model, _) = makeModel(monitor: monitor)

        monitor.send(false)
        monitor.send(true)
        monitor.finish()

        await model.observeConnectivity()

        #expect(model.isOffline == false)
    }

    // MARK: - Helpers

    private func makeModel(
        monitor: MockConnectivityMonitor = MockConnectivityMonitor()
    ) -> (SyncStatusModel, ManualSleeper) {
        let sleeper = ManualSleeper()

        let model = SyncStatusModel(
            monitor: monitor,
            successDuration: .seconds(2),
            sleep: { duration in
                await sleeper.sleep(duration)
            }
        )

        return (model, sleeper)
    }
}

// MARK: - Mocks

@MainActor
private final class MockConnectivityMonitor: ConnectivityMonitorProtocol {

    private let stream: AsyncStream<Bool>
    private let continuation: AsyncStream<Bool>.Continuation

    init() {
        let pair = AsyncStream<Bool>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
    }

    func connectivityUpdates() -> AsyncStream<Bool> {
        stream
    }

    func send(_ isOnline: Bool) {
        continuation.yield(isOnline)
    }

    func finish() {
        continuation.finish()
    }
}

/// A sleep replacement that only returns when the test calls `elapse()`.
@MainActor
private final class ManualSleeper {

    private(set) var requestedDurations: [Duration] = []

    private var sleepers: [CheckedContinuation<Void, Never>] = []

    private var waiter: (
        expectedCount: Int,
        continuation: CheckedContinuation<Void, Never>
    )?

    func sleep(_ duration: Duration) async {
        requestedDurations.append(duration)

        if let waiter, requestedDurations.count >= waiter.expectedCount {
            self.waiter = nil
            waiter.continuation.resume()
        }

        await withCheckedContinuation { continuation in
            sleepers.append(continuation)
        }
    }

    func waitUntilSleeping(count: Int = 1) async {
        if requestedDurations.count >= count {
            return
        }

        await withCheckedContinuation { continuation in
            waiter = (count, continuation)
        }
    }

    func elapseOldest() {
        guard !sleepers.isEmpty else {
            return
        }

        sleepers.removeFirst().resume()
    }

    func elapse() {
        let pending = sleepers
        sleepers.removeAll()

        for continuation in pending {
            continuation.resume()
        }
    }
}
