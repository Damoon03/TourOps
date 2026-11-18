//
//  SyncIssueTests.swift
//  TourOpsTests
//

import Foundation
import Testing
@testable import TourOps

struct SyncIssueTests {

    @Test
    func onlyConflictAndFailedOperationsBecomeIssues() {
        let entityID = UUID()

        let operations = [
            makeOperation(entityID: entityID, status: .pending),
            makeOperation(entityID: entityID, status: .processing),
            makeOperation(entityID: UUID(), status: .pending)
        ]

        #expect(SyncIssue.issues(from: operations).isEmpty)
    }

    @Test
    func operationsOfOneEntityFormOneIssue() {
        let entityID = UUID()

        let operations = [
            makeOperation(
                entityID: entityID,
                operationType: .update,
                status: .failed
            ),
            makeOperation(
                entityID: entityID,
                operationType: .delete,
                status: .failed
            )
        ]

        let issues = SyncIssue.issues(from: operations)

        #expect(issues.count == 1)
        #expect(issues.first?.entityID == entityID)
        #expect(issues.first?.operationTypes == [.update, .delete])
    }

    @Test
    func conflictTakesPriorityOverFailed() {
        let entityID = UUID()

        let operations = [
            makeOperation(entityID: entityID, status: .failed),
            makeOperation(entityID: entityID, status: .conflict)
        ]

        #expect(SyncIssue.issues(from: operations).first?.kind == .conflict)
    }

    @Test
    func failedOnlyIsAFailedIssue() {
        let operations = [makeOperation(entityID: UUID(), status: .failed)]

        #expect(SyncIssue.issues(from: operations).first?.kind == .failed)
    }

    @Test
    func issuesAreOrderedByTheirOldestOperation() {
        let older = UUID()
        let newer = UUID()

        let operations = [
            makeOperation(entityID: newer, status: .failed, createdAt: 2_000),
            makeOperation(entityID: older, status: .conflict, createdAt: 1_000)
        ]

        let ids = SyncIssue.issues(from: operations).map(\.entityID)

        #expect(ids == [older, newer])
    }

    // MARK: - Helpers

    private func makeOperation(
        entityID: UUID,
        operationType: SyncOperationType = .update,
        status: SyncOperationStatus,
        createdAt: TimeInterval = 1_000
    ) -> SyncOperation {
        SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .team,
            operationType: operationType,
            payload: nil,
            version: 1,
            createdAt: Date(timeIntervalSince1970: createdAt),
            status: status,
            retryCount: 0
        )
    }
}
