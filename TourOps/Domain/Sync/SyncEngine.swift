//
//  SyncEngine.swift
//  TourOps
//
//  Created by Damoon saber on 9/8/1405 AP.
//

import Foundation

@MainActor
final class SyncEngine: SyncEngineProtocol {

    private let syncOperationRepository: SyncOperationRepositoryProtocol
    private let syncService: SyncServiceProtocol

    init(
        syncOperationRepository: SyncOperationRepositoryProtocol,
        syncService: SyncServiceProtocol
    ) {
        self.syncOperationRepository = syncOperationRepository
        self.syncService = syncService
    }

    func sync() async {
        do {
            let operations =
                try await syncOperationRepository.fetchPendingOperations()

            for operation in operations {
                do {
                    try await syncService.execute(operation)
                    try await syncOperationRepository.delete(operation)
                } catch {
                    continue
                }
            }
        } catch {
            return
        }
    }
}
