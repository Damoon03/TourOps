//
//  SyncConflictResolving.swift
//  TourOps
//
//  The user's way out of a conflict or failed operation. Nothing here removes
//  or relabels an operation except as the direct result of an explicit user
//  action.
//

import Foundation

@MainActor
protocol SyncConflictResolving {

    /// Replaces the local state of the entity with the server's, even when
    /// the version numbers are equal, and removes the entity's operations.
    /// A row that no longer exists on the server is removed locally.
    func useServerVersion(for issue: SyncIssue) async throws

    /// Puts the entity's failed operations back in the queue and requests a
    /// sync. It helps only when the cause was temporary.
    func retry(_ issue: SyncIssue) async throws

    /// Gives up a failed change. A failed update or delete is replaced by the
    /// server's state. A failed create was never on the server, so the local
    /// item is removed.
    func discard(_ issue: SyncIssue) async throws
}

enum SyncResolutionError: Error, Equatable {

    /// A sync cycle is already running, so the action did not run.
    case busy

    /// The server returned no rows, so its state for the entity cannot be
    /// confirmed. Nothing was changed.
    case remoteStateUnverified

    /// Other local items still reference the entity being discarded.
    case hasDependentItems

    /// The entity has no operation of the kind the action works on.
    case noUnresolvedOperation
}

extension SyncResolutionError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .busy:
            return "Sync is running. Try again in a moment."
        case .remoteStateUnverified:
            return "The server returned no data, so its current version "
                + "can’t be confirmed. Check your connection or account "
                + "and try again."
        case .hasDependentItems:
            return "Other items depend on this one. Resolve or discard "
                + "their changes first."
        case .noUnresolvedOperation:
            return "This item no longer needs attention."
        }
    }
}
