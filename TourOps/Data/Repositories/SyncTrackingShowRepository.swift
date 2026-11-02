//
//  SyncTrackingShowRepository.swift
//  TourOps
//
//  Created by Damoon saber on 8/6/1405 AP.
//

import Foundation
import SwiftData

@MainActor
final class SyncTrackingShowRepository: ShowRepositoryProtocol {

    private let showRepository: SwiftDataShowRepository
    private let syncOperationRepository: SwiftDataSyncOperationRepository
    private let modelContext: ModelContext
    private let syncScheduler: SyncSchedulerProtocol

    init(
        showRepository: SwiftDataShowRepository,
        syncOperationRepository: SwiftDataSyncOperationRepository,
        modelContext: ModelContext,
        syncScheduler: SyncSchedulerProtocol
    ) {
        self.showRepository = showRepository
        self.syncOperationRepository = syncOperationRepository
        self.modelContext = modelContext
        self.syncScheduler = syncScheduler
    }

    // MARK: - Fetch

    func fetchShows() async throws -> [Show] {
        try await showRepository.fetchShows()
    }

    func fetchShow(id: UUID) async throws -> Show {
        try await showRepository.fetchShow(id: id)
    }

    // MARK: - Create

    func createShow(_ show: Show) async throws {
        try showRepository.stageCreateShow(show)

        let payloadData = try JSONCoding.encoder.encode(
            ShowMapper.toDTO(show)
        )

        let payload = String(
            data: payloadData,
            encoding: .utf8
        )

        let operation = SyncOperation(
            id: UUID(),
            entityID: show.id,
            entityType: .show,
            operationType: .create,
            payload: payload,
            version: show.version,
            createdAt: Date(),
            status: .pending,
            retryCount: 0
        )

        try syncOperationRepository.stageAdd(operation)
        try modelContext.save()

        syncScheduler.scheduleSync()
    }

    // MARK: - Update

    func updateShow(_ show: Show) async throws {
        try await requireNoUnresolvedSyncIssue(for: show.id)

        try showRepository.stageUpdateShow(show)

        let payloadData = try JSONCoding.encoder.encode(
            ShowMapper.toDTO(show, version: show.version + 1)
        )

        let payload = String(
            data: payloadData,
            encoding: .utf8
        )

        let operation = SyncOperation(
            id: UUID(),
            entityID: show.id,
            entityType: .show,
            operationType: .update,
            payload: payload,
            version: show.version,
            createdAt: Date(),
            status: .pending,
            retryCount: 0
        )

        try syncOperationRepository.stageAdd(operation)
        try modelContext.save()

        syncScheduler.scheduleSync()
    }

    // MARK: - Delete

    func deleteShow(id: UUID) async throws {
        try await requireNoUnresolvedSyncIssue(for: id)

        let show = try await showRepository.fetchShow(id: id)

        try showRepository.stageDeleteShow(id: id)

        let operation = SyncOperation(
            id: UUID(),
            entityID: id,
            entityType: .show,
            operationType: .delete,
            payload: nil,
            version: show.version,
            createdAt: Date(),
            status: .pending,
            retryCount: 0
        )

        try syncOperationRepository.stageAdd(operation)
        try modelContext.save()

        syncScheduler.scheduleSync()
    }

    // MARK: - Unresolved sync issues

    /// Edits and deletes of an entity with a `.conflict` or `.failed`
    /// operation are rejected. A new operation would be based on the local
    /// version, which can match the server's version and silently overwrite
    /// another device's change. Nothing is staged and no operation is changed.
    private func requireNoUnresolvedSyncIssue(
        for entityID: UUID
    ) async throws {
        let operations = try await syncOperationRepository.fetchOperations(
            forEntityID: entityID
        )

        let hasUnresolvedIssue = operations.contains {
            $0.status == .conflict || $0.status == .failed
        }

        if hasUnresolvedIssue {
            throw RepositoryError.unresolvedSyncIssue
        }
    }
}
