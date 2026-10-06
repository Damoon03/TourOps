//
//  ShowReconciler.swift
//  TourOps
//
//  Created by Damoon saber on 7/14/1405 AP.
//

import Foundation

@MainActor
final class ShowReconciler {

    private let showRepository: SwiftDataShowRepository
    private let syncOperationRepository: SyncOperationRepositoryProtocol

    init(
        showRepository: SwiftDataShowRepository,
        syncOperationRepository: SyncOperationRepositoryProtocol
    ) {
        self.showRepository = showRepository
        self.syncOperationRepository = syncOperationRepository
    }

    func reconcile(remoteShows: [Show]) async throws {
        let localShows = try await showRepository.fetchShows()

        let localShowsByID = Dictionary(
            uniqueKeysWithValues: localShows.map { ($0.id, $0) }
        )

        let remoteShowIDs = Set(
            remoteShows.map(\.id)
        )

        // Remote shows
        for remoteShow in remoteShows {
            let operations = try await syncOperationRepository.fetchOperations(
                forEntityID: remoteShow.id
            )

            let hasBlockingDelete = operations.contains {
                $0.operationType == .delete &&
                ($0.status == .pending || $0.status == .processing)
            }

            guard let localShow = localShowsByID[remoteShow.id] else {
                if !hasBlockingDelete {
                    try showRepository.stageCreateShow(remoteShow)
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

            guard remoteShow.version > localShow.version else {
                continue
            }

            try showRepository.stageApplyRemoteShow(remoteShow)
        }

        // Local shows missing from remote
        for localShow in localShows {
            guard !remoteShowIDs.contains(localShow.id) else {
                continue
            }

            let operations = try await syncOperationRepository.fetchOperations(
                forEntityID: localShow.id
            )

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

            try showRepository.stageDeleteShow(id: localShow.id)
        }

        try showRepository.save()
    }
}
