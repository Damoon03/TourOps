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
    private let reconciler: ShowReconciler

    init(
        pullService: ShowPullServiceProtocol,
        reconciler: ShowReconciler
    ) {
        self.pullService = pullService
        self.reconciler = reconciler
    }

    func pullShows() async throws {
        let remoteShows = try await pullService.fetchShows()

        try await reconciler.reconcile(
            remoteShows: remoteShows
        )
    }
}
