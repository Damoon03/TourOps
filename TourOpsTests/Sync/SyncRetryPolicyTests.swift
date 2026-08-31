//
//  SyncRetryPolicyTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

struct SyncRetryPolicyTests {

    // MARK: - Should Retry

    @Test
    func shouldRetryReturnsTrueWhenRetryCountIsBelowLimit() {

        let policy = SyncRetryPolicy(
            maxRetryCount: 3
        )

        let operation = makeOperation(
            retryCount: 2
        )

        #expect(
            policy.shouldRetry(operation) == true
        )
    }

    @Test
    func shouldRetryReturnsFalseWhenRetryCountReachedLimit() {

        let policy = SyncRetryPolicy(
            maxRetryCount: 3
        )

        let operation = makeOperation(
            retryCount: 3
        )

        #expect(
            policy.shouldRetry(operation) == false
        )
    }

    // MARK: - Next Retry Count

    @Test
    func nextRetryCountIncrementsRetryCount() {

        let policy = SyncRetryPolicy()

        let operation = makeOperation(
            retryCount: 1
        )

        let nextCount = policy.nextRetryCount(
            for: operation
        )

        #expect(
            nextCount == 2
        )
    }

    @Test
    func nextRetryCountWorksForFirstRetry() {

        let policy = SyncRetryPolicy()

        let operation = makeOperation(
            retryCount: 0
        )

        let nextCount = policy.nextRetryCount(
            for: operation
        )

        #expect(
            nextCount == 1
        )
    }

    // MARK: - Helpers

    private func makeOperation(
        retryCount: Int
    ) -> SyncOperation {

        SyncOperation(
            id: UUID(),
            entityID: UUID(),
            entityType: .show,
            operationType: .create,
            createdAt: Date(),
            status: .failed,
            retryCount: retryCount
        )
    }
}
