//
//  SwiftDataTeamRepositoryTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 6/2/1405 AP.
//
import Testing
import SwiftData
@testable import TourOps
import Foundation

@MainActor
struct SwiftDataTeamRepositoryTests {

    @Test(.disabled("SwiftData runtime issue — investigate later"))
    func createAndFetchTeam() throws {

        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        let container = try ModelContainer(
            for: TeamEntity.self,
            configurations: configuration
        )

        let context = ModelContext(container)

        let team = TeamEntity(
            id: UUID(),
            name: "Test Band",
            genre: "Rock",
            country: "UK",
            city: "London",
            createdAt: Date()
        )

        context.insert(team)

        let descriptor = FetchDescriptor<TeamEntity>()
        let entities = try context.fetch(descriptor)

        #expect(entities.count == 1)
        #expect(entities.first?.id == team.id)
        #expect(entities.first?.name == "Test Band")
    }
}
