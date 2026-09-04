//
//  SyncOperation.swift
//  TourOps
//

import Foundation

enum SyncEntityType: String, Codable {
    case team
    case tour
    case show
}

enum SyncOperationType: String, Codable {
    case create
    case update
    case delete
}

enum SyncOperationStatus: String, Codable {
    case pending
    case processing
    case failed
}

struct SyncOperation: Identifiable, Equatable {
    let id: UUID
    let entityID: UUID
    let entityType: SyncEntityType
    let operationType: SyncOperationType
    let payload: String?
    let version: Int
    let createdAt: Date
    var status: SyncOperationStatus
    var retryCount: Int
}
