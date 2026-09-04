//
//  SwiftDataShowRepository.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataShowRepository: ShowRepositoryProtocol {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch

    func fetchShows() async throws -> [Show] {
        let descriptor = FetchDescriptor<ShowEntity>(
            sortBy: [
                SortDescriptor(\.date)
            ]
        )

        let entities = try modelContext.fetch(descriptor)

        return entities.map { $0.toDomain() }
    }

    func fetchShow(id: UUID) async throws -> Show {
        let descriptor = FetchDescriptor<ShowEntity>(
            predicate: #Predicate { $0.id == id }
        )

        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        return entity.toDomain()
    }

    // MARK: - Create

    func createShow(_ show: Show) async throws {
        try stageCreateShow(show)
        try modelContext.save()
    }

    func stageCreateShow(_ show: Show) throws {
        let showID = show.id

        let descriptor = FetchDescriptor<ShowEntity>(
            predicate: #Predicate { $0.id == showID }
        )

        if let _ = try modelContext.fetch(descriptor).first {
            throw RepositoryError.duplicate
        }

        let entity = ShowEntity(show: show)

        modelContext.insert(entity)
    }

    // MARK: - Update

    func updateShow(_ show: Show) async throws {
        try stageUpdateShow(show)
        try modelContext.save()
    }

    func stageUpdateShow(_ show: Show) throws {
        let showID = show.id

        let descriptor = FetchDescriptor<ShowEntity>(
            predicate: #Predicate { $0.id == showID }
        )

        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        guard entity.version == show.version else {
            throw RepositoryError.staleVersion
        }

        entity.tourID = show.tourID
        entity.name = show.name
        entity.venue = show.venue
        entity.city = show.city
        entity.date = show.date
        entity.version += 1
    }

    // MARK: - Delete

    func deleteShow(id: UUID) async throws {
        try stageDeleteShow(id: id)
        try modelContext.save()
    }

    func stageDeleteShow(id: UUID) throws {
        let descriptor = FetchDescriptor<ShowEntity>(
            predicate: #Predicate { $0.id == id }
        )

        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        modelContext.delete(entity)
    }
}
