//
//  ShowReconcilerTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 7/14/1405 AP.
//

import Foundation
import Testing
import SwiftData

@testable import TourOps

@MainActor
struct ShowReconcilerTests {

    private let container: ModelContainer

    init() throws {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        self.container = try ModelContainer(
            for:
                TeamEntity.self,
                TourEntity.self,
                ShowEntity.self,
                SyncOperationEntity.self,
            configurations: configuration
        )
    }

    private var showRepository: SwiftDataShowRepository {
        SwiftDataShowRepository(
            modelContext: container.mainContext
        )
    }

    private var syncOperationRepository: SwiftDataSyncOperationRepository {
        SwiftDataSyncOperationRepository(
            modelContext: container.mainContext
        )
    }

    // MARK: - Remote Shows

    @Test
    func newRemoteShowIsCreatedLocally() async throws {
        let remoteShow = makeShow()

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: [remoteShow]
        )

        let localShow = try await showRepository.fetchShow(
            id: remoteShow.id
        )

        #expect(localShow == remoteShow)
    }

    @Test
    func newerRemoteShowUpdatesLocalShow() async throws {
        let localShow = makeShow(
            version: 1,
            name: "Original Show"
        )

        try await showRepository.createShow(localShow)

        let remoteShow = makeShow(
            id: localShow.id,
            tourID: localShow.tourID,
            version: 2,
            name: "Updated Show"
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: [remoteShow]
        )

        let fetchedShow = try await showRepository.fetchShow(
            id: localShow.id
        )

        #expect(fetchedShow.name == "Updated Show")
        #expect(fetchedShow.version == 2)
    }

    @Test
    func sameVersionRemoteShowDoesNotUpdateLocalShow() async throws {
        let localShow = makeShow(
            version: 2,
            name: "Local Show"
        )

        try await showRepository.createShow(localShow)

        let remoteShow = makeShow(
            id: localShow.id,
            tourID: localShow.tourID,
            version: 2,
            name: "Remote Show"
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: [remoteShow]
        )

        let fetchedShow = try await showRepository.fetchShow(
            id: localShow.id
        )

        #expect(fetchedShow.name == "Local Show")
        #expect(fetchedShow.version == 2)
    }

    @Test
    func olderRemoteShowDoesNotUpdateLocalShow() async throws {
        let localShow = makeShow(
            version: 3,
            name: "Local Show"
        )

        try await showRepository.createShow(localShow)

        let remoteShow = makeShow(
            id: localShow.id,
            tourID: localShow.tourID,
            version: 2,
            name: "Older Remote Show"
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: [remoteShow]
        )

        let fetchedShow = try await showRepository.fetchShow(
            id: localShow.id
        )

        #expect(fetchedShow.name == "Local Show")
        #expect(fetchedShow.version == 3)
    }

    // MARK: - Blocking Operations

    @Test
    func pendingOperationPreservesLocalShow() async throws {
        let localShow = makeShow(
            version: 1,
            name: "Local Show"
        )

        try await showRepository.createShow(localShow)

        try await syncOperationRepository.add(
            makeOperation(
                entityID: localShow.id,
                operationType: .update,
                status: .pending
            )
        )

        let remoteShow = makeShow(
            id: localShow.id,
            tourID: localShow.tourID,
            version: 2,
            name: "Remote Show"
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: [remoteShow]
        )

        let fetchedShow = try await showRepository.fetchShow(
            id: localShow.id
        )

        #expect(fetchedShow.name == "Local Show")
        #expect(fetchedShow.version == 1)
    }

    @Test
    func processingOperationPreservesLocalShow() async throws {
        let localShow = makeShow(
            version: 1,
            name: "Local Show"
        )

        try await showRepository.createShow(localShow)

        try await syncOperationRepository.add(
            makeOperation(
                entityID: localShow.id,
                operationType: .update,
                status: .processing
            )
        )

        let remoteShow = makeShow(
            id: localShow.id,
            tourID: localShow.tourID,
            version: 2,
            name: "Remote Show"
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: [remoteShow]
        )

        let fetchedShow = try await showRepository.fetchShow(
            id: localShow.id
        )

        #expect(fetchedShow.name == "Local Show")
        #expect(fetchedShow.version == 1)
    }

    @Test
    func conflictOperationPreservesLocalShow() async throws {
        let localShow = makeShow(
            version: 1,
            name: "Local Show"
        )

        try await showRepository.createShow(localShow)

        try await syncOperationRepository.add(
            makeOperation(
                entityID: localShow.id,
                operationType: .update,
                status: .conflict
            )
        )

        let remoteShow = makeShow(
            id: localShow.id,
            tourID: localShow.tourID,
            version: 2,
            name: "Remote Show"
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: [remoteShow]
        )

        let fetchedShow = try await showRepository.fetchShow(
            id: localShow.id
        )

        #expect(fetchedShow.name == "Local Show")
        #expect(fetchedShow.version == 1)
    }

    @Test
    func failedOperationAllowsRemoteShowToWin() async throws {
        let localShow = makeShow(
            version: 1,
            name: "Local Show"
        )

        try await showRepository.createShow(localShow)

        try await syncOperationRepository.add(
            makeOperation(
                entityID: localShow.id,
                operationType: .update,
                status: .failed
            )
        )

        let remoteShow = makeShow(
            id: localShow.id,
            tourID: localShow.tourID,
            version: 2,
            name: "Remote Show"
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: [remoteShow]
        )

        let fetchedShow = try await showRepository.fetchShow(
            id: localShow.id
        )

        #expect(fetchedShow.name == "Remote Show")
        #expect(fetchedShow.version == 2)
    }

    // MARK: - Local Shows Missing From Remote

    @Test
    func emptyRemoteResponsePreservesLocalShow() async throws {
        let localShow = makeShow(
            version: 1,
            name: "Local Show"
        )

        try await showRepository.createShow(localShow)

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: []
        )

        let fetchedShow = try await showRepository.fetchShow(
            id: localShow.id
        )

        #expect(fetchedShow == localShow)
    }

    @Test
    func localOnlyShowIsDeletedWhenRemoteContainsOtherShows() async throws {
        let localShow = makeShow(
            version: 1,
            name: "Local Show"
        )

        try await showRepository.createShow(localShow)

        let remoteShow = makeShow(
            version: 1,
            name: "Remote Show"
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: [remoteShow]
        )

        await #expect(throws: RepositoryError.notFound) {
            try await showRepository.fetchShow(id: localShow.id)
        }

        let fetchedRemoteShow = try await showRepository.fetchShow(
            id: remoteShow.id
        )

        #expect(fetchedRemoteShow == remoteShow)
    }

    @Test
    func pendingOperationPreservesLocalOnlyShow() async throws {
        let localShow = makeShow()

        try await showRepository.createShow(localShow)

        try await syncOperationRepository.add(
            makeOperation(
                entityID: localShow.id,
                operationType: .update,
                status: .pending
            )
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: []
        )

        let fetchedShow = try await showRepository.fetchShow(
            id: localShow.id
        )

        #expect(fetchedShow.id == localShow.id)
    }

    @Test
    func processingOperationPreservesLocalOnlyShow() async throws {
        let localShow = makeShow()

        try await showRepository.createShow(localShow)

        try await syncOperationRepository.add(
            makeOperation(
                entityID: localShow.id,
                operationType: .update,
                status: .processing
            )
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: []
        )

        let fetchedShow = try await showRepository.fetchShow(
            id: localShow.id
        )

        #expect(fetchedShow.id == localShow.id)
    }

    @Test
    func conflictOperationPreservesLocalOnlyShow() async throws {
        let localShow = makeShow()

        try await showRepository.createShow(localShow)

        try await syncOperationRepository.add(
            makeOperation(
                entityID: localShow.id,
                operationType: .update,
                status: .conflict
            )
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: []
        )

        let fetchedShow = try await showRepository.fetchShow(
            id: localShow.id
        )

        #expect(fetchedShow.id == localShow.id)
    }

    @Test
    func failedCreateOperationPreservesLocalOnlyShow() async throws {
        let localShow = makeShow(
            version: 2,
            name: "Local Show"
        )

        try await showRepository.createShow(localShow)

        try await syncOperationRepository.add(
            makeOperation(
                entityID: localShow.id,
                operationType: .create,
                status: .failed
            )
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: []
        )

        let fetchedShow = try await showRepository.fetchShow(
            id: localShow.id
        )

        #expect(fetchedShow == localShow)
    }

    // MARK: - Pending Delete Resurrection

    @Test
    func remoteShowWithPendingDeleteIsNotRecreated() async throws {
        let show = makeShow()

        try await syncOperationRepository.add(
            makeOperation(
                entityID: show.id,
                operationType: .delete,
                status: .pending
            )
        )

        let reconciler = ShowReconciler(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository
        )

        try await reconciler.reconcile(
            remoteShows: [show]
        )

        let shows = try await showRepository.fetchShows()

        #expect(shows.isEmpty)
    }

    // MARK: - Helpers

    private func makeShow(
        id: UUID = UUID(),
        tourID: UUID = UUID(),
        version: Int = 1,
        name: String = "Show"
    ) -> Show {
        Show(
            id: id,
            tourID: tourID,
            name: name,
            venue: "Olympia",
            city: "Paris",
            date: Date(timeIntervalSince1970: 100),
            createdAt: Date(timeIntervalSince1970: 200),
            version: version
        )
    }

    private func makeOperation(
        entityID: UUID,
        operationType: SyncOperationType,
        status: SyncOperationStatus
    ) -> SyncOperation {
        SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .show,
            operationType: operationType,
            payload: nil,
            version: 1,
            createdAt: Date(),
            status: status,
            retryCount: 0
        )
    }
}

