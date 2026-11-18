//
//  RepositoryError.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import Foundation

enum RepositoryError: Error {
    case notFound
    case duplicate
    case staleVersion
    case unresolvedSyncIssue
}

extension RepositoryError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .unresolvedSyncIssue:
            return "This item has a sync problem that needs attention. "
                + "Close any open edit screen, then tap the sync status "
                + "to resolve or retry it."
        case .notFound, .duplicate, .staleVersion:
            return nil
        }
    }
}
