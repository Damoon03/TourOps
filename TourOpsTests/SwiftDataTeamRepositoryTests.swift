//
//  SwiftDataTeamRepositoryTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 6/2/1405 AP.
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct SwiftDataTeamRepositoryTests {

    private let container: ModelContainer

    init() throws {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        self.container = try ModelContainer(
            for: TeamEntity.self,
            configurations: configuration
        )
    }

    private var repository: SwiftDataTeamRepository {
        SwiftDataTeamRepository(
            modelContext: container.mainContext
        )
    }

    @Test
    func createAndFetchTeam() async throws {
        let team = Team(
            id: UUID(),
            name: "Test Band",
            genre: "Rock",
            country: "UK",
            city: "London",
            createdAt: Date()
        )

        try await repository.createTeam(team)

        let fetchedTeam = try await repository.fetchTeam(id: team.id)

        #expect(fetchedTeam == team)
    }
    
    @Test
    func createDuplicateTeamThrowsDuplicateError() async throws {
        let teamID = UUID()

        let firstTeam = Team(
            id: teamID,
            name: "First Band",
            genre: "Rock",
            country: "UK",
            city: "London",
            createdAt: Date()
        )

        let secondTeam = Team(
            id: teamID,
            name: "Second Band",
            genre: "Jazz",
            country: "UK",
            city: "Manchester",
            createdAt: Date()
        )

        try await repository.createTeam(firstTeam)

        await #expect(throws: RepositoryError.duplicate) {
            try await repository.createTeam(secondTeam)
        }
    }
    
    @Test
    func fetchTeamThrowsNotFoundForMissingTeam() async throws {
        let missingID = UUID()

        await #expect(throws: RepositoryError.notFound) {
            try await repository.fetchTeam(id: missingID)
        }
    }
    
    @Test
    func updateTeamThrowsNotFoundForMissingTeam() async throws {
        let team = Team(
            id: UUID(),
            name: "Missing Band",
            genre: "Rock",
            country: "UK",
            city: "London",
            createdAt: Date()
        )

        await #expect(throws: RepositoryError.notFound) {
            try await repository.updateTeam(team)
        }
    }

    @Test
    func deleteTeamThrowsNotFoundForMissingTeam() async throws {
        let missingID = UUID()

        await #expect(throws: RepositoryError.notFound) {
            try await repository.deleteTeam(id: missingID)
        }
    }
}
