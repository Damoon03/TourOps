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
            createdAt: Date(timeIntervalSince1970: 100)
        )

        let secondUpdate = makeOperation(
            entityID: entityID,
            type: .update,
            createdAt: Date(timeIntervalSince1970: 200)
        )

        let result = reducer.reduce([
            firstUpdate,
            secondUpdate
        ])

        #expect(result.count == 1)
        #expect(result.first?.operationType == .update)
        #expect(result.first?.entityID == entityID)
    }


    // MARK: - Create + Update

    @Test
    func createFollowedByUpdateKeepsCreateOperation() {

        let reducer = SyncOperationReducer()

        let entityID = UUID()

        let create = makeOperation(
            entityID: entityID,
            type: .create
        )

        let update = makeOperation(
            entityID: entityID,
            type: .update
        )

        let result = reducer.reduce([
            create,
            update
        ])

        #expect(result.count == 1)
        #expect(result.first?.operationType == .create)
        #expect(result.first?.entityID == entityID)
    }


    // MARK: - Create + Delete

    @Test
    func createFollowedByDeleteRemovesOperation() {

        let reducer = SyncOperationReducer()

        let entityID = UUID()

        let create = makeOperation(
            entityID: entityID,
            type: .create
        )

        let delete = makeOperation(
            entityID: entityID,
            type: .delete
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
            type: .update
        )

        let delete = makeOperation(
            entityID: entityID,
            type: .delete
        )

        let result = reducer.reduce([
            update,
            delete
        ])

        #expect(result.count == 1)
        #expect(result.first?.operationType == .delete)
        #expect(result.first?.entityID == entityID)
    }


    // MARK: - Helpers

    private func makeOperation(
        entityID: UUID = UUID(),
        type: SyncOperationType,
        createdAt: Date = Date()
    ) -> SyncOperation {

        SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .show,
            operationType: type,
            createdAt: createdAt,
            status: .pending,
            retryCount: 0
        )
    }
}
