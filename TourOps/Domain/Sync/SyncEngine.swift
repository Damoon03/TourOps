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
    private let retryPolicy: SyncRetryPolicy

    init(
        syncOperationRepository: SyncOperationRepositoryProtocol,
        syncService: SyncServiceProtocol,
        retryPolicy: SyncRetryPolicy
    ) {
        self.syncOperationRepository = syncOperationRepository
        self.syncService = syncService
        self.retryPolicy = retryPolicy
    }

    func sync() async {

        do {
            let operations =
                try await syncOperationRepository
                    .fetchPendingOperations()

            for operation in operations {

                var processingOperation = operation
                processingOperation.status = .processing

                do {
                    try await syncOperationRepository
                        .update(processingOperation)

                    try await syncService
                        .execute(processingOperation)

                    try await syncOperationRepository
                        .delete(processingOperation)

                } catch {

                    await handleFailure(
                        processingOperation
                    )
                }
            }

        } catch {
            return
        }
    }

    private func handleFailure(
        _ operation: SyncOperation
    ) async {

        var updatedOperation = operation

        if retryPolicy.shouldRetry(operation) {

            updatedOperation.retryCount =
                retryPolicy.nextRetryCount(
                    for: operation
                )

            updatedOperation.status = .pending

        } else {

            updatedOperation.status = .failed
        }

        try? await syncOperationRepository
            .update(updatedOperation)
    }
}
