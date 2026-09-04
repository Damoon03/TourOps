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

    // MARK: - Fetch

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

    // MARK: - Create

    func createTeam(_ team: Team) async throws {
        try stageCreateTeam(team)
        try modelContext.save()
    }

    func stageCreateTeam(_ team: Team) throws {
        let teamID = team.id

        let descriptor = FetchDescriptor<TeamEntity>(
            predicate: #Predicate { $0.id == teamID }
        )

        if let _ = try modelContext.fetch(descriptor).first {
            throw RepositoryError.duplicate
        }

        let entity = TeamEntity(team: team)

        modelContext.insert(entity)
    }

    // MARK: - Update

    func updateTeam(_ team: Team) async throws {
        try stageUpdateTeam(team)
        try modelContext.save()
    }

    func stageUpdateTeam(_ team: Team) throws {
        let teamID = team.id

        let descriptor = FetchDescriptor<TeamEntity>(
            predicate: #Predicate { $0.id == teamID }
        )

        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        guard entity.version == team.version else {
            throw RepositoryError.staleVersion
        }

        entity.name = team.name
        entity.genre = team.genre
        entity.country = team.country
        entity.city = team.city
        entity.version += 1
    }

    // MARK: - Delete

    func deleteTeam(id: UUID) async throws {
        try stageDeleteTeam(id: id)
        try modelContext.save()
    }

    func stageDeleteTeam(id: UUID) throws {
        let descriptor = FetchDescriptor<TeamEntity>(
            predicate: #Predicate { $0.id == id }
        )

        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound
        }

        modelContext.delete(entity)
    }
}
