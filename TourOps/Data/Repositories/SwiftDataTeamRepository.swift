//
//  SwiftDataTeamRepository.swift
//  TourOps
//
//  Created by Damoon saber on 6/1/1405 AP.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataTeamRepository: TeamRepositoryProtocol {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchTeams() async throws -> [Team] {
        let descriptor = FetchDescriptor<TeamEntity>()

        let entities = try modelContext.fetch(descriptor)

        return entities.map { $0.toDomain() }
    }

    func fetchTeam(id: UUID) async throws -> Team {
        let descriptor = FetchDescriptor<TeamEntity>(
            predicate: #Predicate { $0.id == id }
        )

        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        return entity.toDomain()
    }

    func createTeam(_ team: Team) async throws {
        let entity = TeamEntity(team: team)

        modelContext.insert(entity)

        try modelContext.save()
    }

    func updateTeam(_ team: Team) async throws {
        let teamID = team.id

        let descriptor = FetchDescriptor<TeamEntity>(
            predicate: #Predicate { $0.id == teamID }
        )

        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        entity.name = team.name
        entity.genre = team.genre
        entity.country = team.country
        entity.city = team.city

        try modelContext.save()
    }

    func deleteTeam(id: UUID) async throws {
        let descriptor = FetchDescriptor<TeamEntity>(
            predicate: #Predicate { $0.id == id }
        )

        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        modelContext.delete(entity)

        try modelContext.save()
    }
}
