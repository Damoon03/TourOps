//
//  SyncOperationReducer.swift
//  TourOps
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation

struct SyncOperationReducer {

    func reduce(
        _ operations: [SyncOperation]
    ) -> [SyncOperation] {

        var reducedOperations: [UUID: SyncOperation] = [:]

        for operation in operations {

            let entityID = operation.entityID

            guard let existing = reducedOperations[entityID] else {
                reducedOperations[entityID] = operation
                continue
            }

            let merged = merge(
                existing,
                operation
            )

            if let merged {
                reducedOperations[entityID] = merged
            } else {
                reducedOperations.removeValue(
                    forKey: entityID
                )
            }
        }

        return reducedOperations.values.sorted {
            $0.createdAt < $1.createdAt
        }
    }


    private func merge(
        _ first: SyncOperation,
        _ second: SyncOperation
    ) -> SyncOperation? {

        switch (
            first.operationType,
            second.operationType
        ) {

        case (.create, .update):
            return first

        case (.create, .delete):
            return nil

        case (.update, .update):
            return second

        case (.update, .delete):
            return second

        default:
            return second
        }
    }
}
