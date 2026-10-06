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

    func pullTours() async throws {
        let remoteTours = try await pullService.fetchTours()

        try await reconciler.reconcile(
            remoteTours: remoteTours
        )
    }
}
