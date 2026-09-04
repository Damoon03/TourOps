//
//  SwiftDataSyncOperationRepository.swift
//  TourOps
//
//  Created by Damoon saber on 9/6/1405 AP.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataSyncOperationRepository: SyncOperationRepositoryProtocol {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch

    func fetchPendingOperations() async throws -> [SyncOperation] {
        let pendingStatus = SyncOperationStatus.pending.rawValue

        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate {
                $0.status == pendingStatus
            },
            sortBy: [
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )

        let entities = try modelContext.fetch(descriptor)

        return entities.map { $0.toDomain() }
    }

    // MARK: - Create

    func add(_ operation: SyncOperation) async throws {
        try stageAdd(operation)
        try modelContext.save()
    }

    func stageAdd(_ operation: SyncOperation) throws {
        let operationID = operation.id

        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate { $0.id == operationID }
        )

        if let _ = try modelContext.fetch(descriptor).first {
            throw RepositoryError.duplicate
        }

        let entity = SyncOperationEntity(operation: operation)

        modelContext.insert(entity)
    }

    // MARK: - Update

    func update(_ operation: SyncOperation) async throws {
        try stageUpdate(operation)
        try modelContext.save()
    }

    func stageUpdate(_ operation: SyncOperation) throws {
        let operationID = operation.id

        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate { $0.id == operationID }
        )

        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        entity.entityID = operation.entityID
        entity.entityType = operation.entityType.rawValue
        entity.operationType = operation.operationType.rawValue
        entity.payload = operation.payload
        entity.version = operation.version
        entity.status = operation.status.rawValue
        entity.createdAt = operation.createdAt
        entity.retryCount = operation.retryCount
    }

    // MARK: - Delete

    func delete(_ operation: SyncOperation) async throws {
        try stageDelete(operation)
        try modelContext.save()
    }

    func stageDelete(_ operation: SyncOperation) throws {
        let operationID = operation.id

        let descriptor = FetchDescriptor<SyncOperationEntity>(
            predicate: #Predicate { $0.id == operationID }
        )

        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        modelContext.delete(entity)
    }
}
