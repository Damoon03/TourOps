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

    private var pullTask: Task<Void, Error>?
    private var pullRequested = false

    func pullTeams() async throws {
        if let pullTask {
            pullRequested = true
            try await pullTask.value
            return
        }

        let task = Task { @MainActor in
            defer {
                self.pullTask = nil
            }

            repeat {
                self.pullRequested = false

                let remoteTeams = try await self.pullService.fetchTeams()

                try await self.reconciler.reconcile(
                    remoteTeams: remoteTeams
                )
            } while self.pullRequested
        }

        pullTask = task
        try await task.value
    }
}
