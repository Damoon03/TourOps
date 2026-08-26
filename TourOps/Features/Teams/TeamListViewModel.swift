//
//  TeamListViewModel.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import Foundation
import Observation

@MainActor
@Observable
final class TeamListViewModel {

    private let repository: TeamRepositoryProtocol

    var teams: [Team] = []
    var isLoading = false
    var errorMessage: String?

    init(repository: TeamRepositoryProtocol) {
        self.repository = repository
    }

    func loadTeams() async {
        isLoading = true
        errorMessage = nil

        do {
            teams = try await repository.fetchTeams()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func createTeam(_ team: Team) async {
        do {
            try await repository.createTeam(team)
            await loadTeams()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTeam(_ team: Team) async {
        do {
            try await repository.updateTeam(team)
            await loadTeams()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTeam(_ team: Team) async {
        do {
            try await repository.deleteTeam(id: team.id)
            await loadTeams()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
