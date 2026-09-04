//
//  SwiftDataShowRepositoryTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct SwiftDataShowRepositoryTests {

    private let container: ModelContainer

    init() throws {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        self.container = try ModelContainer(
            for: ShowEntity.self,
            configurations: configuration
        )
    }

    private var repository: SwiftDataShowRepository {
        SwiftDataShowRepository(
            modelContext: container.mainContext
        )
    }

    @Test
    func createAndFetchShow() async throws {
        let show = Show(
            id: UUID(),
            tourID: UUID(),
            name: "London Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        try await repository.createShow(show)

        let fetchedShow = try await repository.fetchShow(
            id: show.id
        )

        #expect(fetchedShow == show)
    }

    @Test
    func createDuplicateShowThrowsDuplicateError() async throws {
        let showID = UUID()
        let tourID = UUID()

        let firstShow = Show(
            id: showID,
            tourID: tourID,
            name: "London Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        let secondShow = Show(
            id: showID,
            tourID: tourID,
            name: "Manchester Show",
            venue: "AO Arena",
            city: "Manchester",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        try await repository.createShow(firstShow)

        await #expect(throws: RepositoryError.duplicate) {
            try await repository.createShow(secondShow)
        }
    }

    @Test
    func fetchShowThrowsNotFoundForMissingShow() async throws {
        let missingID = UUID()

        await #expect(throws: RepositoryError.notFound) {
            try await repository.fetchShow(id: missingID)
        }
    }

    @Test
    func updateShowSuccessfullyUpdatesShow() async throws {
        let show = Show(
            id: UUID(),
            tourID: UUID(),
            name: "London Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        try await repository.createShow(show)

        let updatedShow = Show(
            id: show.id,
            tourID: show.tourID,
            name: "Updated London Show",
            venue: "Wembley Arena",
            city: "London",
            date: show.date,
            createdAt: show.createdAt,
            version: show.version
        )

        try await repository.updateShow(updatedShow)

        let fetchedShow = try await repository.fetchShow(
            id: show.id
        )

        #expect(fetchedShow.name == "Updated London Show")
        #expect(fetchedShow.venue == "Wembley Arena")
        #expect(fetchedShow.version == 2)
    }

    @Test
    func updateShowThrowsStaleVersionForOutdatedShow() async throws {
        let show = Show(
            id: UUID(),
            tourID: UUID(),
            name: "London Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        try await repository.createShow(show)

        let outdatedShow = Show(
            id: show.id,
            tourID: show.tourID,
            name: "Outdated London Show",
            venue: "Wembley Arena",
            city: "London",
            date: show.date,
            createdAt: show.createdAt,
            version: 0
        )

        await #expect(throws: RepositoryError.staleVersion) {
            try await repository.updateShow(outdatedShow)
        }
    }

    @Test
    func updateShowThrowsNotFoundForMissingShow() async throws {
        let show = Show(
            id: UUID(),
            tourID: UUID(),
            name: "Missing Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        await #expect(throws: RepositoryError.notFound) {
            try await repository.updateShow(show)
        }
    }

    @Test
    func deleteShowSuccessfullyDeletesShow() async throws {
        let show = Show(
            id: UUID(),
            tourID: UUID(),
            name: "London Show",
            venue: "O2 Arena",
            city: "London",
            date: Date(),
            createdAt: Date(),
            version: 1
        )

        try await repository.createShow(show)
        try await repository.deleteShow(id: show.id)

        await #expect(throws: RepositoryError.notFound) {
            try await repository.fetchShow(id: show.id)
        }
    }

    @Test
    func deleteShowThrowsNotFoundForMissingShow() async throws {
        let missingID = UUID()

        await #expect(throws: RepositoryError.notFound) {
            try await repository.deleteShow(id: missingID)
        }
    }
}
