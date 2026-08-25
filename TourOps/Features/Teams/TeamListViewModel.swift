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

    private(set) var teams: [Team] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

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

    func createTeam(
        name: String,
        genre: String,
        country: String,
        city: String
    ) async {
        let team = Team(
            id: UUID(),
            name: name,
            genre: genre,
            country: country,
            city: city,
            createdAt: Date()
        )

        do {
            try await repository.createTeam(team)
            await loadTeams()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
