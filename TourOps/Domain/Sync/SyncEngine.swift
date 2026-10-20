//
//  SyncEngine.swift
//  TourOps
//
//  Created by Damoon saber on 6/7/1405 AP.
//

import Foundation

@MainActor
final class SyncEngine: SyncEngineProtocol {

    private let syncOperationRepository: SyncOperationRepositoryProtocol
    private let syncService: SyncServiceProtocol
    private let retryPolicy: SyncRetryPolicy
    private let operationReducer: SyncOperationReducer

    private var isSyncing = false
    private var syncRequested = false

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

    func sync() async -> SyncRunResult {
        guard !Task.isCancelled else {
            return .cancelled
        }

        guard !isSyncing else {
            syncRequested = true
            return .noWork
        }

        isSyncing = true

        defer {
            isSyncing = false
        }

        var didExecuteOperation = false
        var encounteredFailure = false
        var encounteredCancellation = false

        repeat {
            syncRequested = false

            guard !Task.isCancelled else {
                return .cancelled
            }

            do {
                let pendingOperations =
                    try await syncOperationRepository.fetchPendingOperations()

                let groupedOperations = Dictionary(
                    grouping: pendingOperations,
                    by: \.entityID
                )

                let orderedGroups = groupedOperations.values.sorted(
                    by: Self.compareEntityGroups
                )

                for entityOperations in orderedGroups {
                    if Task.isCancelled {
                        return .cancelled
                    }

                    let reducedOperations = operationReducer.reduce(
                        entityOperations
                    )

                    if reducedOperations.isEmpty {
                        for operation in entityOperations {
                            do {
                                try await syncOperationRepository.delete(
                                    operation
                                )
                            } catch {
                                encounteredFailure = true
                            }
                        }

                        continue
                    }

                    let reducedIDs = Set(
                        reducedOperations.map(\.id)
                    )

                    for operation in entityOperations
                    where !reducedIDs.contains(operation.id) {
                        do {
                            try await syncOperationRepository.delete(
                                operation
                            )
                        } catch {
                            encounteredFailure = true
                        }
                    }

                    for operation in reducedOperations {
                        if Task.isCancelled {
                            return .cancelled
                        }

                        let result = await process(
                            operation,
                            relatedOperations: reducedOperations
                        )

                        switch result {
                        case .success:
                            didExecuteOperation = true

                        case .noWork:
                            break

                        case .failure:
                            encounteredFailure = true

                        case .cancelled:
                            encounteredCancellation = true
                        }

                        if encounteredCancellation {
                            return .cancelled
                        }
                    }
                }
            } catch is CancellationError {
                return .cancelled
            } catch {
                encounteredFailure = true
            }
        } while syncRequested && !Task.isCancelled

        if Task.isCancelled {
            return .cancelled
        }

        if encounteredCancellation {
            return .cancelled
        }

        if encounteredFailure {
            return .failure
        }

        return didExecuteOperation ? .success : .noWork
    }

    private func process(
        _ operation: SyncOperation,
        relatedOperations: [SyncOperation]
    ) async -> SyncRunResult {
        do {
            var processingOperation = operation
            processingOperation.status = .processing

            try await syncOperationRepository.update(
                processingOperation
            )

            try await syncService.execute(
                processingOperation
            )

            for relatedOperation in relatedOperations {
                try await syncOperationRepository.delete(
                    relatedOperation
                )
            }

            return .success
        } catch is CancellationError {
            var pendingOperation = operation
            pendingOperation.status = .pending

            try? await syncOperationRepository.update(
                pendingOperation
            )

            return .cancelled
        } catch {
            await handleFailure(
                operation,
                error: error
            )

            return .failure
        }
    }

    private func handleFailure(
        _ operation: SyncOperation,
        error: Error
    ) async {
        if case SyncError.conflict = error {
            var conflictOperation = operation
            conflictOperation.status = .conflict

            try? await syncOperationRepository.update(
                conflictOperation
            )

            return
        }

        if case APIClientError.networkError = error {
            var pendingOperation = operation
            pendingOperation.status = .pending

            try? await syncOperationRepository.update(
                pendingOperation
            )

            return
        }

        if let apiError = error as? APIClientError,
           !apiError.isRetryable {
            var failedOperation = operation
            failedOperation.status = .failed

            try? await syncOperationRepository.update(
                failedOperation
            )

            return
        }

        var failedOperation = operation
        failedOperation.retryCount += 1

        if retryPolicy.shouldRetry(failedOperation) {
            failedOperation.status = .pending
        } else {
            failedOperation.status = .failed
        }

        try? await syncOperationRepository.update(
            failedOperation
        )
    }

    private static func compareEntityGroups(
        _ lhs: [SyncOperation],
        _ rhs: [SyncOperation]
    ) -> Bool {
        let lhsRank = entityTypeRank(lhs.first?.entityType)
        let rhsRank = entityTypeRank(rhs.first?.entityType)

        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        let lhsDate = lhs.map(\.createdAt).min() ?? .distantFuture
        let rhsDate = rhs.map(\.createdAt).min() ?? .distantFuture

        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }

        let lhsID = lhs.first?.entityID.uuidString ?? ""
        let rhsID = rhs.first?.entityID.uuidString ?? ""

        return lhsID < rhsID
    }

    private static func entityTypeRank(
        _ entityType: SyncEntityType?
    ) -> Int {
        switch entityType {
        case .team:
            return 0
        case .tour:
            return 1
        case .show:
            return 2
        case nil:
            return 3
        }
    }
}
