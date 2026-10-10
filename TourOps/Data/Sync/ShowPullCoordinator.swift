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

    private var pullTask: Task<Void, Error>?
    private var pullRequested = false

    func pullShows() async throws {
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

                let remoteShows = try await self.pullService.fetchShows()

                try await self.reconciler.reconcile(
                    remoteShows: remoteShows
                )
            } while self.pullRequested
        }

        pullTask = task
        try await task.value
    }
}
