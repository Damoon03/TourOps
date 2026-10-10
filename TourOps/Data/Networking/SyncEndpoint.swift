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
        operation: SyncOperationType,
        version: Int
    )

    case tour(
        id: UUID,
        operation: SyncOperationType,
        version: Int
    )

    case show(
        id: UUID,
        operation: SyncOperationType,
        version: Int
    )

    var path: String {
        switch self {

        case .team(let id, let operation, let version):
            return makePath(
                table: "teams",
                id: id,
                operation: operation,
                version: version
            )

        case .tour(let id, let operation, let version):
            return makePath(
                table: "tours",
                id: id,
                operation: operation,
                version: version
            )

        case .show(let id, let operation, let version):
            return makePath(
                table: "shows",
                id: id,
                operation: operation,
                version: version
            )
        }
    }

    var method: HTTPMethod {
        switch self {

        case .team(_, let operation, _),
             .tour(_, let operation, _),
             .show(_, let operation, _):

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
        operation: SyncOperationType,
        version: Int
    ) -> String {

        switch operation {

        case .create:
            return "/rest/v1/\(table)"

        case .update:
            return "/rest/v1/\(table)?id=eq.\(id.uuidString)&version=eq.\(version)"

        case .delete:
            return "/rest/v1/\(table)?id=eq.\(id.uuidString)&version=eq.\(version)"
        }
    }
}
