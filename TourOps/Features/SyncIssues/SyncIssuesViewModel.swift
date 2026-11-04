//
//  SyncIssuesViewModel.swift
//  TourOps
//

import Foundation
import Observation

@MainActor
@Observable
final class SyncIssuesViewModel {

    private let resolver: SyncConflictResolving
    private let refreshSignal: DataRefreshSignal

    /// True while an action runs. Other actions are ignored until it ends.
    private(set) var isWorking = false

    private(set) var errorMessage: String?

    init(
        resolver: SyncConflictResolving,
        refreshSignal: DataRefreshSignal
    ) {
        self.resolver = resolver
        self.refreshSignal = refreshSignal
    }

    /// Returns whether the action completed.
    func useServerVersion(for issue: SyncIssue) async -> Bool {
        await perform(bumpsRefresh: true) {
            try await resolver.useServerVersion(for: issue)
        }
    }

    /// Retry only requeues operations. The lists show the same data, so they
    /// do not reload.
    func retry(_ issue: SyncIssue) async -> Bool {
        await perform(bumpsRefresh: false) {
            try await resolver.retry(issue)
        }
    }

    func discard(_ issue: SyncIssue) async -> Bool {
        await perform(bumpsRefresh: true) {
            try await resolver.discard(issue)
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    // MARK: - Private

    private func perform(
        bumpsRefresh: Bool,
        _ action: () async throws -> Void
    ) async -> Bool {
        guard !isWorking else {
            return false
        }

        isWorking = true
        errorMessage = nil

        defer {
            isWorking = false
        }

        do {
            try await action()

            // A resolution can change or remove items, so every list reloads.
            if bumpsRefresh {
                refreshSignal.bump()
            }

            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
