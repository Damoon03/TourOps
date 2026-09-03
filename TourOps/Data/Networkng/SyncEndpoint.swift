//
//  SyncEndpoint.swift
//  TourOps
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation

enum SyncEndpoint: Endpoint {

    case team(
        id: UUID,
        operation: SyncOperationType
    )

    case tour(
        id: UUID,
        operation: SyncOperationType
    )

    case show(
        id: UUID,
        operation: SyncOperationType
    )


    var path: String {

        switch self {

        case .team(let id, _):
            return "/teams/\(id.uuidString)"

        case .tour(let id, _):
            return "/tours/\(id.uuidString)"

        case .show(let id, _):
            return "/shows/\(id.uuidString)"
        }
    }


    var method: HTTPMethod {

        switch self {

        case .team(_, let operation),
             .tour(_, let operation),
             .show(_, let operation):

            switch operation {

            case .create:
                return .POST

            case .update:
                return .PUT

            case .delete:
                return .DELETE
            }
        }
    }
}
