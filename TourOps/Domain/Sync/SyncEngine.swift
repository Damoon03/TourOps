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
    private let operationReducer: SyncOperationReducer

    init(
        syncOperationRepository: SyncOperationRepositoryProtocol,
        syncService: SyncServiceProtocol,
        retryPolicy: SyncRetryPolicy,
        operationReducer: SyncOperationReducer
    ) {
        self.syncOperationRepository = syncOperationRepository
        self.syncService = syncService
        self.retryPolicy = retryPolicy
        self.operationReducer = operationReducer
    }


    func sync() async {

        do {

            let pendingOperations =
                try await syncOperationRepository.fetchPendingOperations()

            let operations =
                operationReducer.reduce(
                    pendingOperations
                )

            for operation in operations {

                await process(operation)
            }

        } catch {

            return
        }
    }


    private func process(
        _ operation: SyncOperation
    ) async {

        do {

            var processingOperation = operation
            processingOperation.status = .processing

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

            await handleFailure(
                operation
            )
        }
    }


    private func handleFailure(
        _ operation: SyncOperation
    ) async {

        var failedOperation = operation

        failedOperation.retryCount += 1

        if retryPolicy.shouldRetry(
            failedOperation
        ) {

            failedOperation.status = .pending

        } else {

            failedOperation.status = .failed
        }


        try? await syncOperationRepository.update(
            failedOperation
        )
    }
}
