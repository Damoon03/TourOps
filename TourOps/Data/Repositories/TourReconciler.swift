//
//  TourReconciler.swift
//  TourOps
//
//  Created by Damoon saber on 7/13/1405 AP.
//

import Foundation

@MainActor
final class TourReconciler {

    private let tourRepository: SwiftDataTourRepository
    private let syncOperationRepository: SyncOperationRepositoryProtocol

    init(
        tourRepository: SwiftDataTourRepository,
        syncOperationRepository: SyncOperationRepositoryProtocol
    ) {
        self.tourRepository = tourRepository
        self.syncOperationRepository = syncOperationRepository
    }

    func reconcile(remoteTours: [Tour]) async throws {
        let localTours = try await tourRepository.fetchTours()

        let localToursByID = Dictionary(
            uniqueKeysWithValues: localTours.map { ($0.id, $0) }
        )

        let remoteTourIDs = Set(remoteTours.map(\.id))

        // An empty remote response is not sufficient evidence
        // that all local tours have been deleted remotely.
        let shouldApplyRemoteDeletions =
            !remoteTours.isEmpty || localTours.isEmpty

        // Remote tours
        for remoteTour in remoteTours {
            let operations = try await syncOperationRepository.fetchOperations(
                forEntityID: remoteTour.id
            )

            let hasBlockingDelete = operations.contains {
                $0.operationType == .delete &&
                ($0.status == .pending || $0.status == .processing)
            }

            guard let localTour = localToursByID[remoteTour.id] else {
                if !hasBlockingDelete {
                    try tourRepository.stageCreateTour(remoteTour)
                }
                continue
            }

            let hasBlockingOperation = operations.contains {
                switch $0.status {
                case .pending, .processing, .conflict:
                    true
                case .failed:
                    false
                }
            }

            if hasBlockingOperation {
                continue
            }

            guard remoteTour.version > localTour.version else {
                continue
            }

            try tourRepository.stageApplyRemoteTour(remoteTour)
        }

        // Local tours missing from remote
        if shouldApplyRemoteDeletions {
            for localTour in localTours {
                guard !remoteTourIDs.contains(localTour.id) else {
                    continue
                }

                let operations = try await syncOperationRepository.fetchOperations(
                    forEntityID: localTour.id
                )

                let hasBlockingOperation = operations.contains {
                    switch $0.status {
                    case .pending, .processing, .conflict, .failed:
                        true
                    }
                }

                if hasBlockingOperation {
                    continue
                }

                try tourRepository.stageDeleteTour(id: localTour.id)
            }
        }

        try tourRepository.save()
    }
}
