//
//  SyncOperationReducerTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

struct SyncOperationReducerTests {

    // MARK: - Update + Update

    @Test
    func updateOperationsForSameEntityAreReducedToSingleOperation() {
        let reducer = SyncOperationReducer()
        let entityID = UUID()

        let firstUpdate = makeOperation(
            entityID: entityID,
            type: .update,
            version: 1,
            createdAt: Date(timeIntervalSince1970: 100)
        )

        let secondUpdate = makeOperation(
            entityID: entityID,
            type: .update,
            version: 2,
            createdAt: Date(timeIntervalSince1970: 200)
        )

        let result = reducer.reduce([
            firstUpdate,
            secondUpdate
        ])

        #expect(result.count == 1)
        #expect(result.first?.operationType == .update)
        #expect(result.first?.entityID == entityID)

        // The latest update should be kept.
        #expect(result.first?.version == 2)
    }

    // MARK: - Create + Update

    @Test
    func createFollowedByUpdateKeepsCreateOperation() {
        let reducer = SyncOperationReducer()
        let entityID = UUID()

        let create = makeOperation(
            entityID: entityID,
            type: .create,
            version: 1
        )

        let update = makeOperation(
            entityID: entityID,
            type: .update,
            version: 2
        )

        let result = reducer.reduce([
            create,
            update
        ])

        #expect(result.count == 1)
        #expect(result.first?.operationType == .create)
        #expect(result.first?.entityID == entityID)

        // The create operation keeps its original version.
        #expect(result.first?.version == 1)
    }

    // MARK: - Create + Delete

    @Test
    func createFollowedByDeleteRemovesOperation() {
        let reducer = SyncOperationReducer()
        let entityID = UUID()

        let create = makeOperation(
            entityID: entityID,
            type: .create,
            version: 1
        )

        let delete = makeOperation(
            entityID: entityID,
            type: .delete,
            version: 2
        )

        let result = reducer.reduce([
            create,
            delete
        ])

        #expect(result.isEmpty)
    }

    // MARK: - Update + Delete

    @Test
    func updateFollowedByDeleteKeepsDeleteOperation() {
        let reducer = SyncOperationReducer()
        let entityID = UUID()

        let update = makeOperation(
            entityID: entityID,
            type: .update,
            version: 2
        )

        let delete = makeOperation(
            entityID: entityID,
            type: .delete,
            version: 3
        )

        let result = reducer.reduce([
            update,
            delete
        ])

        #expect(result.count == 1)
        #expect(result.first?.operationType == .delete)
        #expect(result.first?.entityID == entityID)

        // The delete operation keeps its own version.
        #expect(result.first?.version == 3)
    }

    // MARK: - Helpers

    private func makeOperation(
        entityID: UUID = UUID(),
        type: SyncOperationType,
        version: Int = 1,
        createdAt: Date = Date()
    ) -> SyncOperation {
        SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .show,
            operationType: type,
            payload: nil,
            version: version,
            createdAt: createdAt,
            status: .pending,
            retryCount: 0
        )
    }
}
