//
//  TourPullCoordinator.swift
//  TourOps
//
//  Created by Damoon saber on 7/13/1405 AP.
//

import Foundation

@MainActor
final class TourPullCoordinator {

    private let pullService: TourPullServiceProtocol

    init(
        pullService: TourPullServiceProtocol
    ) {
        self.pullService = pullService
    }

    func pullTours() async throws -> [Tour] {
        try await pullService.fetchTours()
    }
}
