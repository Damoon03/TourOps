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
                var processingOperation = operation
                processingOperation.status = .processing

                do {
                    try await syncOperationRepository.update(
                        processingOperation
                    )

                    try await syncService.execute(
                        processingOperation
                    )

                    try await syncOperationRepository.delete(
                        processingOperation
                    )

                } catch {
                    var failedOperation = processingOperation
                    failedOperation.status = .failed

                    try? await syncOperationRepository.update(
                        failedOperation
                    )
                }
            }

        } catch {
            return
        }
    }
}
