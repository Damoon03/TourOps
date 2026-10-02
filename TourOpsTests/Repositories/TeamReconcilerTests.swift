//
//  TeamReconcilerTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 7/10/1405 AP.
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct TeamReconcilerTests {

    private let container: ModelContainer

    init() throws {
        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        self.container = try ModelContainer(
            for: TeamEntity.self,
            SyncOperationEntity.self,
            configurations: configuration
        )
    }

    private var teamRepository: SwiftDataTeamRepository {
        SwiftDataTeamRepository(
            modelContext: container.mainContext
        )
    }

    private var syncOperationRepository: SwiftDataSyncOperationRepository {
        SwiftDataSyncOperationRepository(
            modelContext: container.mainContext
        )
    }

    private var reconciler: TeamReconciler {
        TeamReconciler(
            teamRepository: teamRepository,
            syncOperationRepository: syncOperationRepository
        )
    }

    // MARK: - Remote-only

    @Test
    func remoteOnlyTeamIsInserted() async throws {
        let remoteTeam = makeTeam(
            name: "Remote Band",
            version: 3
        )

        try await reconciler.reconcile(
            remoteTeams: [remoteTeam]
        )

        let teams = try await teamRepository.fetchTeams()

        #expect(teams.count == 1)
        #expect(teams.first?.id == remoteTeam.id)
        #expect(teams.first?.name == "Remote Band")
        #expect(teams.first?.version == 3)
    }

    // MARK: - Newer Remote

    @Test
    func newerRemoteTeamReplacesLocalTeam() async throws {
        let localTeam = makeTeam(
            name: "Local Band",
            genre: "Rock",
            version: 2
        )

        try await teamRepository.createTeam(localTeam)

        let remoteTeam = makeTeam(
            id: localTeam.id,
            name: "Remote Band",
            genre: "Jazz",
            version: 5
        )

        try await reconciler.reconcile(
            remoteTeams: [remoteTeam]
        )

        let fetchedTeam = try await teamRepository.fetchTeam(
            id: localTeam.id
        )

        #expect(fetchedTeam.name == "Remote Band")
        #expect(fetchedTeam.genre == "Jazz")
        #expect(fetchedTeam.version == 5)
    }

    // MARK: - Equal Version

    @Test
    func equalVersionKeepsLocalTeamUnchanged() async throws {
        let localTeam = makeTeam(
            name: "Local Band",
            genre: "Rock",
            version: 3
        )

        try await teamRepository.createTeam(localTeam)

        let remoteTeam = makeTeam(
            id: localTeam.id,
            name: "Remote Band",
            genre: "Jazz",
            version: 3
        )

        try await reconciler.reconcile(
            remoteTeams: [remoteTeam]
        )

        let fetchedTeam = try await teamRepository.fetchTeam(
            id: localTeam.id
        )

        #expect(fetchedTeam.name == "Local Band")
        #expect(fetchedTeam.genre == "Rock")
        #expect(fetchedTeam.version == 3)
    }

    // MARK: - Older Remote

    @Test
    func olderRemoteTeamDoesNotOverwriteLocalTeam() async throws {
        let localTeam = makeTeam(
            name: "Local Band",
            version: 5
        )

        try await teamRepository.createTeam(localTeam)

        let remoteTeam = makeTeam(
            id: localTeam.id,
            name: "Old Remote Band",
            version: 3
        )

        try await reconciler.reconcile(
            remoteTeams: [remoteTeam]
        )

        let fetchedTeam = try await teamRepository.fetchTeam(
            id: localTeam.id
        )

        #expect(fetchedTeam.name == "Local Band")
        #expect(fetchedTeam.version == 5)
    }

    // MARK: - Blocking Operations

    @Test
    func pendingOperationProtectsLocalTeam() async throws {
        let localTeam = makeTeam(
            name: "Local Band",
            version: 2
        )

        try await teamRepository.createTeam(localTeam)

        let operation = makeOperation(
            entityID: localTeam.id,
            status: .pending,
            version: 2
        )

        try await syncOperationRepository.add(operation)

        let remoteTeam = makeTeam(
            id: localTeam.id,
            name: "Remote Band",
            version: 5
        )

        try await reconciler.reconcile(
            remoteTeams: [remoteTeam]
        )

        let fetchedTeam = try await teamRepository.fetchTeam(
            id: localTeam.id
        )

        #expect(fetchedTeam.name == "Local Band")
        #expect(fetchedTeam.version == 2)
    }

    @Test
    func processingOperationProtectsLocalTeam() async throws {
        let localTeam = makeTeam(
            name: "Local Band",
            version: 2
        )

        try await teamRepository.createTeam(localTeam)

        let operation = makeOperation(
            entityID: localTeam.id,
            status: .processing,
            version: 2
        )

        try await syncOperationRepository.add(operation)

        let remoteTeam = makeTeam(
            id: localTeam.id,
            name: "Remote Band",
            version: 5
        )

        try await reconciler.reconcile(
            remoteTeams: [remoteTeam]
        )

        let fetchedTeam = try await teamRepository.fetchTeam(
            id: localTeam.id
        )

        #expect(fetchedTeam.name == "Local Band")
        #expect(fetchedTeam.version == 2)
    }

    @Test
    func conflictOperationProtectsLocalTeam() async throws {
        let localTeam = makeTeam(
            name: "Local Band",
            version: 2
        )

        try await teamRepository.createTeam(localTeam)

        let operation = makeOperation(
            entityID: localTeam.id,
            status: .conflict,
            version: 2
        )

        try await syncOperationRepository.add(operation)

        let remoteTeam = makeTeam(
            id: localTeam.id,
            name: "Remote Band",
            version: 5
        )

        try await reconciler.reconcile(
            remoteTeams: [remoteTeam]
        )

        let fetchedTeam = try await teamRepository.fetchTeam(
            id: localTeam.id
        )

        #expect(fetchedTeam.name == "Local Band")
        #expect(fetchedTeam.version == 2)
    }

    // MARK: - Failed Operation

    @Test
    func failedOperationDoesNotBlockNewerRemoteTeam() async throws {
        let localTeam = makeTeam(
            name: "Local Band",
            version: 2
        )

        try await teamRepository.createTeam(localTeam)

        let operation = makeOperation(
            entityID: localTeam.id,
            status: .failed,
            version: 2
        )

        try await syncOperationRepository.add(operation)

        let remoteTeam = makeTeam(
            id: localTeam.id,
            name: "Remote Band",
            version: 5
        )

        try await reconciler.reconcile(
            remoteTeams: [remoteTeam]
        )

        let fetchedTeam = try await teamRepository.fetchTeam(
            id: localTeam.id
        )

        #expect(fetchedTeam.name == "Remote Band")
        #expect(fetchedTeam.version == 5)
    }

    // MARK: - Local-only

    @Test
    func localOnlyTeamIsPreserved() async throws {
        let localTeam = makeTeam(
            name: "Local Band",
            version: 2
        )

        try await teamRepository.createTeam(localTeam)

        try await reconciler.reconcile(
            remoteTeams: []
        )

        let fetchedTeam = try await teamRepository.fetchTeam(
            id: localTeam.id
        )

        #expect(fetchedTeam == localTeam)
    }

    // MARK: - Helpers

    private func makeTeam(
        id: UUID = UUID(),
        name: String,
        genre: String = "Rock",
        version: Int
    ) -> Team {
        Team(
            id: id,
            name: name,
            genre: genre,
            country: "UK",
            city: "London",
            createdAt: Date(),
            version: version
        )
    }

    private func makeOperation(
        entityID: UUID,
        status: SyncOperationStatus,
        version: Int
    ) -> SyncOperation {
        SyncOperation(
            id: UUID(),
            entityID: entityID,
            entityType: .team,
            operationType: .update,
            payload: nil,
            version: version,
            createdAt: Date(),
            status: status,
            retryCount: 0
        )
    }
}
