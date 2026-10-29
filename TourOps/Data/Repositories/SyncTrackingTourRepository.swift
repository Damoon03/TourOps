//
//  SyncTrackingTourRepository.swift
//  TourOps
//
//  Created by Damoon saber on 8/6/1405 AP.
//

import Foundation
import SwiftData

@MainActor
final class SyncTrackingTourRepository: TourRepositoryProtocol {

    private let tourRepository: SwiftDataTourRepository
    private let syncOperationRepository: SwiftDataSyncOperationRepository
    private let modelContext: ModelContext
    private let syncScheduler: SyncSchedulerProtocol

    init(
        tourRepository: SwiftDataTourRepository,
        syncOperationRepository: SwiftDataSyncOperationRepository,
        modelContext: ModelContext,
        syncScheduler: SyncSchedulerProtocol
    ) {
        self.tourRepository = tourRepository
        self.syncOperationRepository = syncOperationRepository
        self.modelContext = modelContext
        self.syncScheduler = syncScheduler
    }

    // MARK: - Fetch

    func fetchTours() async throws -> [Tour] {
        try await tourRepository.fetchTours()
    }

    func fetchTour(id: UUID) async throws -> Tour {
        try await tourRepository.fetchTour(id: id)
    }

    // MARK: - Create

    func createTour(_ tour: Tour) async throws {
        try tourRepository.stageCreateTour(tour)

        let payloadData = try JSONCoding.encoder.encode(
            TourMapper.toDTO(tour)
        )

        let payload = String(
            data: payloadData,
            encoding: .utf8
        )

        let operation = SyncOperation(
            id: UUID(),
            entityID: tour.id,
            entityType: .tour,
            operationType: .create,
            payload: payload,
            version: tour.version,
            createdAt: Date(),
            status: .pending,
            retryCount: 0
        )

        try syncOperationRepository.stageAdd(operation)
        try modelContext.save()

        syncScheduler.scheduleSync()
    }

    // MARK: - Update

    func updateTour(_ tour: Tour) async throws {
        try await requireNoUnresolvedSyncIssue(for: tour.id)

        try tourRepository.stageUpdateTour(tour)

        let payloadData = try JSONCoding.encoder.encode(
            TourMapper.toDTO(tour, version: tour.version + 1)
        )

        let payload = String(
            data: payloadData,
            encoding: .utf8
        )

        let operation = SyncOperation(
            id: UUID(),
            entityID: tour.id,
            entityType: .tour,
            operationType: .update,
            payload: payload,
            version: tour.version,
            createdAt: Date(),
            status: .pending,
            retryCount: 0
        )

        try syncOperationRepository.stageAdd(operation)
        try modelContext.save()

        syncScheduler.scheduleSync()
    }

    // MARK: - Delete

    func deleteTour(id: UUID) async throws {
        try await requireNoUnresolvedSyncIssue(for: id)

        let tour = try await tourRepository.fetchTour(id: id)

        try tourRepository.stageDeleteTour(id: id)

        let operation = SyncOperation(
            id: UUID(),
            entityID: id,
            entityType: .tour,
            operationType: .delete,
            payload: nil,
            version: tour.version,
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
