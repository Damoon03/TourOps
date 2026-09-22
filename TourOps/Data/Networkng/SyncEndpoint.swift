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

        case .team(let id, let operation):
            return makePath(
                table: "teams",
                id: id,
                operation: operation
            )

        case .tour(let id, let operation):
            return makePath(
                table: "tours",
                id: id,
                operation: operation
            )

        case .show(let id, let operation):
            return makePath(
                table: "shows",
                id: id,
                operation: operation
            )
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
                return .PATCH

            case .delete:
                return .DELETE
            }
        }
    }

    private func makePath(
        table: String,
        id: UUID,
        operation: SyncOperationType
    ) -> String {

        switch operation {
        case .create:
            return "/rest/v1/\(table)"

        case .update,
             .delete:
            return "/rest/v1/\(table)?id=eq.\(id.uuidString)"
        }
    }
}
