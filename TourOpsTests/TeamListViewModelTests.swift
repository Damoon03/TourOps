//
//  TeamListViewModelTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

struct TeamListViewModelTests {

    final class TestTeamRepository: TeamRepositoryProtocol {

        var teams: [Team] = []
        var error: Error?

        func fetchTeams() async throws -> [Team] {
            if let error {
                throw error
            }

            return teams
        }

        func fetchTeam(id: UUID) async throws -> Team {
            if let error {
                throw error
            }

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

    @Test
    @MainActor
    func loadTeamsSuccessfullyUpdatesTeams() async {

        let repository = TestTeamRepository()

        let team1 = Team(
            id: UUID(),
            name: "Northbound",
            genre: "Rock",
            country: "UK",
            city: "London",
            createdAt: Date()
        )

        let team2 = Team(
            id: UUID(),
            name: "Silver Echo",
            genre: "Indie",
            country: "Germany",
            city: "Berlin",
            createdAt: Date()
        )

        repository.teams = [team1, team2]

        let viewModel = TeamListViewModel(repository: repository)

        await viewModel.loadTeams()

        #expect(viewModel.teams == [team1, team2])
        #expect(viewModel.isLoading == false)
    }

    @Test
    @MainActor
    func loadTeamsFailsWithError() async {

        let repository = TestTeamRepository()

        repository.error = RepositoryError.notFound

        let viewModel = TeamListViewModel(repository: repository)

        await viewModel.loadTeams()

        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.teams.isEmpty)
        #expect(viewModel.isLoading == false)
    }
}
