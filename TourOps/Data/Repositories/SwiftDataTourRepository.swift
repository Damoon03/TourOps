//
//  SwiftDataTourRepository.swift
//  TourOps
//
//  Created by Damoon saber on 8/26/2026.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataTourRepository: TourRepositoryProtocol {

private let modelContext: ModelContext

init(modelContext: ModelContext) {
    self.modelContext = modelContext
}

// MARK: - Fetch

func fetchTours() async throws -> [Tour] {
    let descriptor = FetchDescriptor<TourEntity>(
        sortBy: [
            SortDescriptor(\.startDate)
        ]
    )

    let entities = try modelContext.fetch(descriptor)
    return entities.map { $0.toDomain() }
}

func fetchTour(id: UUID) async throws -> Tour {
    let descriptor = FetchDescriptor<TourEntity>(
        predicate: #Predicate { $0.id == id }
    )

    guard let entity = try modelContext.fetch(descriptor).first else {
        throw RepositoryError.notFound
    }

    return entity.toDomain()
}

// MARK: - Create

func createTour(_ tour: Tour) async throws {
    try stageCreateTour(tour)
    try modelContext.save()
}

func stageCreateTour(_ tour: Tour) throws {
    let tourID = tour.id

    let descriptor = FetchDescriptor<TourEntity>(
        predicate: #Predicate { $0.id == tourID }
    )

    if let _ = try modelContext.fetch(descriptor).first {
        throw RepositoryError.duplicate
    }

    let entity = TourEntity(tour: tour)
    modelContext.insert(entity)
}

// MARK: - Update

func updateTour(_ tour: Tour) async throws {
    try stageUpdateTour(tour)
    try modelContext.save()
}

func stageUpdateTour(_ tour: Tour) throws {
    let tourID = tour.id

    let descriptor = FetchDescriptor<TourEntity>(
        predicate: #Predicate { $0.id == tourID }
    )

    guard let entity = try modelContext.fetch(descriptor).first else {
        throw RepositoryError.notFound
    }

    entity.teamID = tour.teamID
    entity.name = tour.name
    entity.startDate = tour.startDate
    entity.endDate = tour.endDate
}

// MARK: - Delete

func deleteTour(id: UUID) async throws {
    try stageDeleteTour(id: id)
    try modelContext.save()
}

func stageDeleteTour(id: UUID) throws {
    let descriptor = FetchDescriptor<TourEntity>(
        predicate: #Predicate { $0.id == id }
    )

    guard let entity = try modelContext.fetch(descriptor).first else {
        throw RepositoryError.notFound
    }

    modelContext.delete(entity)
}
}
