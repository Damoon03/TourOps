//
//  MockTeamRepositoryTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

struct TourOpsTests {

    @Test
    func fetchTeamsReturnsMockTeams() async throws {
        let repository = MockTeamRepository()

        let teams = try await repository.fetchTeams()

        #expect(teams.count == 2)
        #expect(teams[0].name == "Northbound")
        #expect(teams[1].name == "Silver Echo")
    }

    @Test
    func createTeamAddsTeam() async throws {
        let repository = MockTeamRepository()

        let team = Team(
            id: UUID(),
            name: "New Team",
            genre: "Rock",
            country: "USA",
            city: "New York",
            createdAt: Date()
        )

        try await repository.createTeam(team)

        let teams = try await repository.fetchTeams()

        #expect(teams.count == 3)
        #expect(teams.last?.name == "New Team")
    }

    @Test
    func deleteTeamRemovesTeam() async throws {
        let repository = MockTeamRepository()

        let teams = try await repository.fetchTeams()
        let teamID = try #require(teams.first?.id)

        try await repository.deleteTeam(id: teamID)

        let updatedTeams = try await repository.fetchTeams()

        #expect(updatedTeams.count == 1)
    }
}
