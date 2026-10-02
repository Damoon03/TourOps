//
//  TeamPullCoordinator.swift
//  TourOps
//
//  Created by Damoon saber on 7/10/1405 AP.
//

import Foundation

@MainActor
final class TeamPullCoordinator {

    private let pullService: TeamPullServiceProtocol
    private let reconciler: TeamReconciler

    init(
        pullService: TeamPullServiceProtocol,
        reconciler: TeamReconciler
    ) {
        self.pullService = pullService
        self.reconciler = reconciler
    }

    func pullTeams() async throws {
        let remoteTeams = try await pullService.fetchTeams()

        try await reconciler.reconcile(
            remoteTeams: remoteTeams
        )
    }
}
