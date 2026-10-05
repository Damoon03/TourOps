//
//  TourPullCoordinatorTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 7/13/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

@MainActor
struct TourPullCoordinatorTests {

    @Test
    func pullToursReturnsToursFromService() async throws {
        let expectedTours = [
            Tour(
                id: UUID(),
                teamID: UUID(),
                name: "Summer Tour",
                startDate: Date(),
                endDate: Date().addingTimeInterval(86_400),
                createdAt: Date(),
                version: 1
            )
        ]

        let pullService = MockTourPullService(
            tours: expectedTours
        )

        let coordinator = TourPullCoordinator(
            pullService: pullService
        )

        let tours = try await coordinator.pullTours()

        #expect(tours == expectedTours)
        #expect(pullService.fetchToursCallCount == 1)
    }
}

@MainActor
final class MockTourPullService: TourPullServiceProtocol {

    let tours: [Tour]

    private(set) var fetchToursCallCount = 0

    init(tours: [Tour]) {
        self.tours = tours
    }

    func fetchTours() async throws -> [Tour] {
        fetchToursCallCount += 1
        return tours
    }
}
