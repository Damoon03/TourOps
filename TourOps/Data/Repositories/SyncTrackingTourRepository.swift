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

init(
    tourRepository: SwiftDataTourRepository,
    syncOperationRepository: SwiftDataSyncOperationRepository,
    modelContext: ModelContext
) {
    self.tourRepository = tourRepository
    self.syncOperationRepository = syncOperationRepository
    self.modelContext = modelContext
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

    let operation = SyncOperation(
        id: UUID(),
        entityID: tour.id,
        entityType: .tour,
        operationType: .create,
        payload: nil,
        createdAt: Date(),
        status: .pending,
        retryCount: 0
    )

    try syncOperationRepository.stageAdd(operation)

    try modelContext.save()
}

// MARK: - Update

func updateTour(_ tour: Tour) async throws {
    try tourRepository.stageUpdateTour(tour)

    let operation = SyncOperation(
        id: UUID(),
        entityID: tour.id,
        entityType: .tour,
        operationType: .update,
        payload: nil,
        createdAt: Date(),
        status: .pending,
        retryCount: 0
    )

    try syncOperationRepository.stageAdd(operation)

    try modelContext.save()
}

// MARK: - Delete

func deleteTour(id: UUID) async throws {
    try tourRepository.stageDeleteTour(id: id)

    let operation = SyncOperation(
        id: UUID(),
        entityID: id,
        entityType: .tour,
        operationType: .delete,
        payload: nil,
        createdAt: Date(),
        status: .pending,
        retryCount: 0
    )

    try syncOperationRepository.stageAdd(operation)

    try modelContext.save()
}

}
