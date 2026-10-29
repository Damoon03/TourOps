//
//  SyncStatusModel.swift
//  TourOps
//
//  Connection state and the transient "Synced" confirmation shown by
//  `SyncStatusPill`. The number of unsynced changes is deliberately not held
//  here: the persisted sync queue stays the single source of truth.
//
//  "Synced" reflects a completed push of local changes only. Pull results
//  never feed this model.
//

import Foundation
import Observation

enum SyncStatusPresentation: Equatable {
    case hidden
    case offline(unsyncedCount: Int)
    case unsynced(count: Int)
    case needsAttention(count: Int)
    case synced
}

@MainActor
@Observable
final class SyncStatusModel {

    private(set) var isOffline = false
    private(set) var showsSynced = false

    /// Incremented once for each genuine offline-to-online transition. The
    /// first connectivity event never counts: the model starts online, so an
    /// initial online report is not a reconnect.
    private(set) var reconnectCount = 0

    @ObservationIgnored private let monitor: ConnectivityMonitorProtocol
    @ObservationIgnored private let successDuration: Duration
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void

    @ObservationIgnored private(set) var successExpiryTask: Task<Void, Never>?
    @ObservationIgnored private var successGeneration = 0

    init(
        monitor: ConnectivityMonitorProtocol,
        successDuration: Duration = .seconds(2),
        sleep: @escaping @Sendable (Duration) async throws -> Void = {
            try await Task.sleep(for: $0)
        }
    ) {
        self.monitor = monitor
        self.successDuration = successDuration
        self.sleep = sleep
    }

    // MARK: - Connectivity

    /// Consumes connectivity updates until cancelled. Run it from a view's
    /// `.task` so the underlying monitor is torn down with the view.
    func observeConnectivity() async {
        for await isOnline in monitor.connectivityUpdates() {
            setOnline(isOnline)
        }
    }

    func setOnline(_ isOnline: Bool) {
        let wasOffline = isOffline

        isOffline = !isOnline

        if isOffline {
            clearSuccess()
        } else if wasOffline {
            reconnectCount += 1
        }
    }

    // MARK: - Sync reporting

    /// Called when a local change has been queued.
    func changeQueued() {
        clearSuccess()
    }

    /// Called once per completed scheduler run.
    func recordRunResult(_ result: SyncRunResult) {
        switch result {
        case .success:
            showSuccess()

        case .failure, .cancelled:
            clearSuccess()

        case .noWork:
            break
        }
    }

    // MARK: - Presentation

    /// - Parameters:
    ///   - unsyncedCount: Operations still waiting to be sent.
    ///   - needsAttentionCount: Operations in `.conflict` or `.failed`. They
    ///     do not resolve themselves, so they take priority over every other
    ///     state, including offline.
    func presentation(
        unsyncedCount: Int,
        needsAttentionCount: Int = 0
    ) -> SyncStatusPresentation {
        if needsAttentionCount > 0 {
            return .needsAttention(count: needsAttentionCount)
        }

        if isOffline {
            return .offline(unsyncedCount: unsyncedCount)
        }

        if unsyncedCount > 0 {
            return .unsynced(count: unsyncedCount)
        }

        return showsSynced ? .synced : .hidden
    }

    // MARK: - Transient success

    private func showSuccess() {
        // A push that completes while offline cannot be shown as synced.
        guard !isOffline else {
            return
        }

        successExpiryTask?.cancel()
        successGeneration += 1
        showsSynced = true

        let generation = successGeneration
        let duration = successDuration
        let sleep = self.sleep

        successExpiryTask = Task { [weak self] in
            try? await sleep(duration)

            guard !Task.isCancelled else {
                return
            }

            self?.expireSuccess(generation: generation)
        }
    }

    private func expireSuccess(generation: Int) {
        guard generation == successGeneration else {
            return
        }

        showsSynced = false
        successExpiryTask = nil
    }

    private func clearSuccess() {
        successExpiryTask?.cancel()
        successExpiryTask = nil
        successGeneration += 1
        showsSynced = false
    }
}
