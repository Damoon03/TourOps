//
//  MockTeamRepository.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import Foundation

final class MockTeamRepository: TeamRepositoryProtocol {

    private var teams: [Team] = [
        Team(
            id: UUID(),
            name: "Northbound",
            genre: "Alternative Rock",
            country: "UK",
            city: "London",
            createdAt: Date()
        ),
        Team(
            id: UUID(),
            name: "Silver Echo",
            genre: "Indie Rock",
            country: "Germany",
            city: "Berlin",
            createdAt: Date()
        )
    ]
    func fetchTeams() async throws -> [Team] {
        teams
    }

    func fetchTeam(id: UUID) async throws -> Team {
        guard let team = teams.first(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }

        return team
    }

    func createTeam(_ team: Team) async throws {
        teams.append(team)
    }

    func updateTeam(_ team: Team) async throws {
        guard let index = teams.firstIndex(where: { $0.id == team.id }) else {
            throw RepositoryError.notFound
        }

        teams[index] = team
    }

    func deleteTeam(id: UUID) async throws {
        guard let index = teams.firstIndex(where: { $0.id == id }) else {
            throw RepositoryError.notFound
        }

        teams.remove(at: index)
    }
}

