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
    func updateOperationsForSameEntityAreReducedToSingleOperation() throws {
        
        let reducer = SyncOperationReducer()
        let entityID = UUID()

        let firstUpdate = makeOperation(
            entityID: entityID,
            type: .update,
            version: 1,
            createdAt: Date(timeIntervalSince1970: 100),
            payload: #"{"name":"First Update","version":1}"#
        )

        let secondUpdate = makeOperation(
            entityID: entityID,
            type: .update,
            version: 2,
            createdAt: Date(timeIntervalSince1970: 200),
            payload: #"{"name":"Second Update","version":2}"#
        )

        let result = reducer.reduce([
            firstUpdate,
            secondUpdate
        ])

        let reduced = try #require(result.first)

        #expect(result.count == 1)
        #expect(reduced.operationType == .update)
        #expect(reduced.entityID == entityID)
        #expect(reduced.id == firstUpdate.id)
        #expect(reduced.createdAt == firstUpdate.createdAt)
        #expect(reduced.status == firstUpdate.status)
        #expect(reduced.retryCount == firstUpdate.retryCount)

        // Keep the original base version and the latest payload.
        #expect(reduced.version == 1)
        #expect(reduced.payload == secondUpdate.payload)
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
    
    @Test
    func createFollowedByMultipleUpdatesKeepsLatestPayload() {
        let reducer = SyncOperationReducer()

        let entityID = UUID()

        let create = makeOperation(
            entityID: entityID,
            type: .create,
            version: 1,
            payload: #"{"name":"Original"}"#
        )

        let firstUpdate = makeOperation(
            entityID: entityID,
            type: .update,
            version: 2,
            payload: #"{"name":"First Update"}"#
        )

        let latestUpdate = makeOperation(
            entityID: entityID,
            type: .update,
            version: 3,
            payload: #"{"name":"Latest Update"}"#
        )

        let result = reducer.reduce([
            create,
            firstUpdate,
            latestUpdate
        ])

        #expect(result.count == 1)
        #expect(result.first?.operationType == .create)
        #expect(result.first?.entityID == entityID)
        #expect(result.first?.version == 1)
        #expect(result.first?.payload == latestUpdate.payload)
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
            version: 4
        )

        let result = reducer.reduce([
            update,
            delete
        ])

        #expect(result.count == 1)
        #expect(result.first?.operationType == .delete)
        #expect(result.first?.entityID == entityID)

        // The delete operation keeps the original base version.
        #expect(result.first?.version == 2)
        #expect(result.first?.id == update.id)
        #expect(result.first?.createdAt == update.createdAt)
    }

    // MARK: - Helpers

    private func makeOperation(
        entityID: UUID = UUID(),
        type: SyncOperationType,
        version: Int = 1,
        createdAt: Date = Date(),
        payload: String? = nil
    ) -> SyncOperation {
        SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .show,
            operationType: type,
            payload: payload,
            version: version,
            createdAt: createdAt,
            status: .pending,
            retryCount: 0
        )
    }
}
