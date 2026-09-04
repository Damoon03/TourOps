//
//  SyncOperationEntity.swift
//  TourOps
//

import Foundation
import SwiftData

@Model
final class SyncOperationEntity {

    var id: UUID
    var entityID: UUID
    var entityType: String
    var operationType: String
    var payload: String?
    var createdAt: Date
    var status: String
    var retryCount: Int
    var version: Int = 1
    
    init(operation: SyncOperation) {
        self.id = operation.id
        self.entityID = operation.entityID
        self.entityType = operation.entityType.rawValue
        self.operationType = operation.operationType.rawValue
        self.payload = operation.payload
        self.version = operation.version
        self.createdAt = operation.createdAt
        self.status = operation.status.rawValue
        self.retryCount = operation.retryCount
    }

    func toDomain() -> SyncOperation {
        guard
            let entityType = SyncEntityType(rawValue: entityType),
            let operationType = SyncOperationType(rawValue: operationType),
            let status = SyncOperationStatus(rawValue: status)
        else {
            fatalError("Invalid SyncOperationEntity data")
        }

        return SyncOperation(
            id: id,
            entityID: entityID,
            entityType: entityType,
            operationType: operationType,
            payload: payload,
            version: version,
            createdAt: createdAt,
            status: status,
            retryCount: retryCount
        )
    }
}
