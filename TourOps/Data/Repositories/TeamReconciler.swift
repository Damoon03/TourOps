//
//  TeamReconciler.swift
//  TourOps
//

import Foundation

@MainActor
final class TeamReconciler {
    private let teamRepository: SwiftDataTeamRepository
    private let syncOperationRepository: SyncOperationRepositoryProtocol

    init(
        teamRepository: SwiftDataTeamRepository,
        syncOperationRepository: SyncOperationRepositoryProtocol
    ) {
        self.teamRepository = teamRepository
        self.syncOperationRepository = syncOperationRepository
    }

    func reconcile(remoteTeams: [Team]) async throws {
        let localTeams = try await teamRepository.fetchTeams()

        let localTeamsByID = Dictionary(
            uniqueKeysWithValues: localTeams.map { ($0.id, $0) }
        )

        let remoteTeamIDs = Set(
            remoteTeams.map(\.id)
        )

        let shouldApplyRemoteDeletions =
            !remoteTeams.isEmpty || localTeams.isEmpty

        // Remote teams
        for remoteTeam in remoteTeams {
            let operations = try await syncOperationRepository.fetchOperations(
                forEntityID: remoteTeam.id
            )

            let hasBlockingDelete = operations.contains {
                $0.operationType == .delete &&
                ($0.status == .pending || $0.status == .processing)
            }

            guard let localTeam = localTeamsByID[remoteTeam.id] else {
                if !hasBlockingDelete {
                    try teamRepository.stageCreateTeam(remoteTeam)
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

            guard remoteTeam.version > localTeam.version else {
                continue
            }

            try teamRepository.stageApplyRemoteTeam(remoteTeam)
        }

        // Local teams missing from remote
        if shouldApplyRemoteDeletions {
            for localTeam in localTeams {
                guard !remoteTeamIDs.contains(localTeam.id) else {
                    continue
                }

                let operations = try await syncOperationRepository.fetchOperations(
                    forEntityID: localTeam.id
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

                try teamRepository.stageDeleteTeam(id: localTeam.id)
            }
        }

        try teamRepository.save()
    }
}
