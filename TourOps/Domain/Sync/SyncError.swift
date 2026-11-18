//
//  SyncError.swift
//  TourOps
//
//  Created by Damoon saber on 16/6/1405 AP.
//

import Foundation

enum SyncError: Error {
    case conflict

    /// The server rejected a create with HTTP 409 and no row with that id and
    /// owner could be found afterwards, so the create was not applied.
    case createNotConfirmed
}

extension SyncError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .conflict:
            return "The server has a different version of this item."
        case .createNotConfirmed:
            return "The server rejected this new item and it could not be found there, so it was not saved."
        }
    }
}
