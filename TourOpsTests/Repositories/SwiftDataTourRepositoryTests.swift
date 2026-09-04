//
//  SwiftDataTourRepositoryTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct SwiftDataTourRepositoryTests {

    private let container: ModelContainer

    init() throws {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        self.container = try ModelContainer(
            for: TourEntity.self,
            configurations: configuration
        )
    }

    private var repository: SwiftDataTourRepository {
        SwiftDataTourRepository(
            modelContext: container.mainContext
        )
    }

    @Test
    func createAndFetchTour() async throws {
        let tour = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "European Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        try await repository.createTour(tour)

        let fetchedTour = try await repository.fetchTour(
            id: tour.id
        )

        #expect(fetchedTour == tour)
    }

    @Test
    func createDuplicateTourThrowsDuplicateError() async throws {
        let tourID = UUID()
        let teamID = UUID()

        let firstTour = Tour(
            id: tourID,
            teamID: teamID,
            name: "European Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        let secondTour = Tour(
            id: tourID,
            teamID: teamID,
            name: "Summer Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 14),
            createdAt: Date(),
            version: 1
        )

        try await repository.createTour(firstTour)

        await #expect(throws: RepositoryError.duplicate) {
            try await repository.createTour(secondTour)
        }
    }

    @Test
    func fetchTourThrowsNotFoundForMissingTour() async throws {
        let missingID = UUID()

        await #expect(throws: RepositoryError.notFound) {
            try await repository.fetchTour(id: missingID)
        }
    }

    @Test
    func updateTourSuccessfullyUpdatesTour() async throws {
        let tour = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "European Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        try await repository.createTour(tour)

        let updatedTour = Tour(
            id: tour.id,
            teamID: tour.teamID,
            name: "Updated European Tour",
            startDate: tour.startDate,
            endDate: tour.endDate,
            createdAt: tour.createdAt,
            version: tour.version
        )

        try await repository.updateTour(updatedTour)

        let fetchedTour = try await repository.fetchTour(
            id: tour.id
        )

        #expect(fetchedTour.name == "Updated European Tour")
        #expect(fetchedTour.version == 2)
    }

    @Test
    func updateTourThrowsStaleVersionForOutdatedTour() async throws {
        let tour = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "European Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        try await repository.createTour(tour)

        let outdatedTour = Tour(
            id: tour.id,
            teamID: tour.teamID,
            name: "Outdated European Tour",
            startDate: tour.startDate,
            endDate: tour.endDate,
            createdAt: tour.createdAt,
            version: 0
        )

        await #expect(throws: RepositoryError.staleVersion) {
            try await repository.updateTour(outdatedTour)
        }
    }

    @Test
    func updateTourThrowsNotFoundForMissingTour() async throws {
        let tour = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "Missing Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        await #expect(throws: RepositoryError.notFound) {
            try await repository.updateTour(tour)
        }
    }

    @Test
    func deleteTourSuccessfullyDeletesTour() async throws {
        let tour = Tour(
            id: UUID(),
            teamID: UUID(),
            name: "European Tour",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 30),
            createdAt: Date(),
            version: 1
        )

        try await repository.createTour(tour)
        try await repository.deleteTour(id: tour.id)

        await #expect(throws: RepositoryError.notFound) {
            try await repository.fetchTour(id: tour.id)
        }
    }

    @Test
    func deleteTourThrowsNotFoundForMissingTour() async throws {
        let missingID = UUID()

        await #expect(throws: RepositoryError.notFound) {
            try await repository.deleteTour(id: missingID)
        }
    }
}
