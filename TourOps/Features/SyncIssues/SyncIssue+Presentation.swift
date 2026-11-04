//
//  SyncIssue+Presentation.swift
//  TourOps
//
//  The wording the needs-attention sheet shows for an issue.
//

import Foundation

extension SyncIssue {

    var typeName: String {
        switch entityType {
        case .team:
            return "Team"
        case .tour:
            return "Tour"
        case .show:
            return "Show"
        }
    }

    /// `name` is nil when the item no longer exists on this device, which is
    /// the case right after a conflicted delete.
    func title(name: String?) -> String {
        guard let name else {
            return "Deleted \(typeName.lowercased())"
        }

        return "\(typeName): \(name)"
    }

    var explanation: String {
        switch kind {
        case .conflict:
            return operationTypes.contains(.delete)
                ? "You deleted this, but it was changed on the server."
                : "You changed this offline, and it was also changed on the server."
        case .failed:
            return "This change couldn’t be sent."
        }
    }

    func useServerVersionMessage(name: String?) -> String {
        "Your change to \(quotedName(name)) will be replaced by the "
            + "server’s version. This can’t be undone."
    }

    func discardMessage(name: String?) -> String {
        if operationTypes.contains(.create) {
            return "\(quotedName(name)) was never saved to the server. "
                + "It will be removed from this device."
        }

        return "Your change to \(quotedName(name)) will be removed and the "
            + "server’s version restored."
    }

    private func quotedName(_ name: String?) -> String {
        guard let name else {
            return "this \(typeName.lowercased())"
        }

        return "“\(name)”"
    }
}
