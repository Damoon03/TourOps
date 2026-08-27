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

func createShow(_ show: Show) async throws {

    let showID = show.id

    let descriptor = FetchDescriptor<ShowEntity>(
        predicate: #Predicate { $0.id == showID }
    )

    if let _ = try modelContext.fetch(descriptor).first {
        throw RepositoryError.duplicate
    }

    let entity = ShowEntity(show: show)

    modelContext.insert(entity)

    try modelContext.save()
}

func updateShow(_ show: Show) async throws {

    let showID = show.id

    let descriptor = FetchDescriptor<ShowEntity>(
        predicate: #Predicate { $0.id == showID }
    )

    guard let entity = try modelContext.fetch(descriptor).first else {
        throw RepositoryError.notFound
    }

    entity.tourID = show.tourID
    entity.name = show.name
    entity.venue = show.venue
    entity.city = show.city
    entity.date = show.date

    try modelContext.save()
}

func deleteShow(id: UUID) async throws {

    let descriptor = FetchDescriptor<ShowEntity>(
        predicate: #Predicate { $0.id == id }
    )

    guard let entity = try modelContext.fetch(descriptor).first else {
        throw RepositoryError.notFound
    }

    modelContext.delete(entity)

    try modelContext.save()
}

}
