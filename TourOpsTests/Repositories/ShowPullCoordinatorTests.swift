//
//  ShowPullCoordinatorTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 7/14/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

@MainActor
struct ShowPullCoordinatorTests {

    @Test
    func pullShowsReturnsShowsFromService() async throws {
        let expectedShows = [
            Show(
                id: UUID(),
                tourID: UUID(),
                name: "Paris Show",
                venue: "Olympia",
                city: "Paris",
                date: Date(),
                createdAt: Date(),
                version: 1
            )
        ]

        let service = MockShowPullService(
            shows: expectedShows
        )

        let coordinator = ShowPullCoordinator(
            pullService: service
        )

        let shows = try await coordinator.pullShows()

        #expect(shows == expectedShows)
    }
}

@MainActor
private final class MockShowPullService: ShowPullServiceProtocol {

    let shows: [Show]

    init(shows: [Show]) {
        self.shows = shows
    }

    func fetchShows() async throws -> [Show] {
        shows
    }
}
