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
        var createError: Error?
        var updateError: Error?
        var deleteError: Error?

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
            if let createError {
                throw createError
            }

            teams.append(team)
        }

        func updateTeam(_ team: Team) async throws {
            if let updateError {
                throw updateError
            }

            guard let index = teams.firstIndex(where: { $0.id == team.id }) else {
                throw RepositoryError.notFound
            }

            teams[index] = team
        }

        func deleteTeam(id: UUID) async throws {
            if let deleteError {
                throw deleteError
            }

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

    @Test
    @MainActor
    func createTeamSuccessfullyCreatesTeam() async {
        let repository = TestTeamRepository()
        let viewModel = TeamListViewModel(repository: repository)

        let team = Team(
            id: UUID(),
            name: "Test Band",
            genre: "Rock",
            country: "UK",
            city: "London",
            createdAt: Date()
        )

        let success = await viewModel.createTeam(team)

        #expect(success == true)
        #expect(repository.teams == [team])
        #expect(viewModel.teams == [team])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    @MainActor
    func createTeamFailsWithError() async {
        let repository = TestTeamRepository()
        repository.createError = RepositoryError.duplicate

        let viewModel = TeamListViewModel(repository: repository)

        let team = Team(
            id: UUID(),
            name: "Test Band",
            genre: "Rock",
            country: "UK",
            city: "London",
            createdAt: Date()
        )

        let success = await viewModel.createTeam(team)

        #expect(success == false)
        #expect(viewModel.errorMessage != nil)
        #expect(repository.teams.isEmpty)
    }

    @Test
    @MainActor
    func updateTeamSuccessfullyUpdatesTeam() async {
        let repository = TestTeamRepository()

        let originalTeam = Team(
            id: UUID(),
            name: "Original Band",
            genre: "Rock",
            country: "UK",
            city: "London",
            createdAt: Date()
        )

        repository.teams = [originalTeam]

        let viewModel = TeamListViewModel(repository: repository)

        let updatedTeam = Team(
            id: originalTeam.id,
            name: "Updated Band",
            genre: "Indie",
            country: "Germany",
            city: "Berlin",
            createdAt: originalTeam.createdAt
        )

        let success = await viewModel.updateTeam(updatedTeam)

        #expect(success == true)
        #expect(repository.teams == [updatedTeam])
        #expect(viewModel.teams == [updatedTeam])
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    @MainActor
    func updateTeamFailsWithError() async {
        let repository = TestTeamRepository()

        let originalTeam = Team(
            id: UUID(),
            name: "Original Band",
            genre: "Rock",
            country: "UK",
            city: "London",
            createdAt: Date()
        )

        repository.teams = [originalTeam]
        repository.updateError = RepositoryError.notFound

        let viewModel = TeamListViewModel(repository: repository)

        let updatedTeam = Team(
            id: originalTeam.id,
            name: "Updated Band",
            genre: "Indie",
            country: "Germany",
            city: "Berlin",
            createdAt: originalTeam.createdAt
        )

        let success = await viewModel.updateTeam(updatedTeam)

        #expect(success == false)
        #expect(viewModel.errorMessage != nil)
        #expect(repository.teams == [originalTeam])
    }

    @Test
    @MainActor
    func deleteTeamSuccessfullyDeletesTeam() async {
        let repository = TestTeamRepository()

        let team = Team(
            id: UUID(),
            name: "Test Band",
            genre: "Rock",
            country: "UK",
            city: "London",
            createdAt: Date()
        )

        repository.teams = [team]

        let viewModel = TeamListViewModel(repository: repository)

        let success = await viewModel.deleteTeam(team)

        #expect(success == true)
        #expect(repository.teams.isEmpty)
        #expect(viewModel.teams.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    @MainActor
    func deleteTeamFailsWithError() async {
        let repository = TestTeamRepository()

        let team = Team(
            id: UUID(),
            name: "Test Band",
            genre: "Rock",
            country: "UK",
            city: "London",
            createdAt: Date()
        )

        repository.teams = [team]
        repository.deleteError = RepositoryError.notFound

        let viewModel = TeamListViewModel(repository: repository)

        let success = await viewModel.deleteTeam(team)

        #expect(success == false)
        #expect(viewModel.errorMessage != nil)
        #expect(repository.teams == [team])
    }
}
