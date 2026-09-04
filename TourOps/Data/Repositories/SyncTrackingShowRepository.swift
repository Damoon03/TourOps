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

    init(
        showRepository: SwiftDataShowRepository,
        syncOperationRepository: SwiftDataSyncOperationRepository,
        modelContext: ModelContext
    ) {
        self.showRepository = showRepository
        self.syncOperationRepository = syncOperationRepository
        self.modelContext = modelContext
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

        let operation = SyncOperation(
            id: UUID(),
            entityID: show.id,
            entityType: .show,
            operationType: .create,
            payload: nil,
            version: show.version,
            createdAt: Date(),
            status: .pending,
            retryCount: 0
        )

        try syncOperationRepository.stageAdd(operation)
        try modelContext.save()
    }

    // MARK: - Update

    func updateShow(_ show: Show) async throws {
        try showRepository.stageUpdateShow(show)

        let operation = SyncOperation(
            id: UUID(),
            entityID: show.id,
            entityType: .show,
            operationType: .update,
            payload: nil,
            version: show.version,
            createdAt: Date(),
            status: .pending,
            retryCount: 0
        )

        try syncOperationRepository.stageAdd(operation)
        try modelContext.save()
    }

    // MARK: - Delete

    func deleteShow(id: UUID) async throws {
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
    }
}
