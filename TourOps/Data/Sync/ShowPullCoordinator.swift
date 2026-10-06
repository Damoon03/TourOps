//
//  ShowPullCoordinator.swift
//  TourOps
//
//  Created by Damoon saber on 7/14/1405 AP.
//

import Foundation

@MainActor
final class ShowPullCoordinator {

    private let pullService: ShowPullServiceProtocol

    init(
        pullService: ShowPullServiceProtocol
    ) {
        self.pullService = pullService
    }

    func pullShows() async throws -> [Show] {
        try await pullService.fetchShows()
    }
}
