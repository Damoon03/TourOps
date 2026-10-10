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
    private let reconciler: TourReconciler

    init(
        pullService: TourPullServiceProtocol,
        reconciler: TourReconciler
    ) {
        self.pullService = pullService
        self.reconciler = reconciler
    }

    private var pullTask: Task<Void, Error>?
    private var pullRequested = false

    func pullTours() async throws {
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

                let remoteTours = try await self.pullService.fetchTours()

                try await self.reconciler.reconcile(
                    remoteTours: remoteTours
                )
            } while self.pullRequested
        }

        pullTask = task
        try await task.value
    }
}
