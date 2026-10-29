//
//  SyncTrackingTeamRepositoryTests.swift
//  TourOps
//
//  Created by Damoon saber on 9/6/1405 AP.
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct SyncTrackingTeamRepositoryTests {

    // MARK: - Create

    @Test
    func createTeamPersistsTeamAndSyncOperation() async throws {

        let (repository, syncOperationRepository, syncScheduler) =
            try makeRepository()

        let team = makeTeam()

        try await repository.createTeam(team)

        #expect(syncScheduler.scheduleSyncCallCount == 1)

        let persistedTeam = try await repository.fetchTeam(
            id: team.id
        )

        let operations = try await syncOperationRepository
            .fetchPendingOperations()

        #expect(persistedTeam == team)
        #expect(operations.count == 1)

        let operation = try #require(operations.first)

        #expect(operation.entityID == team.id)
        #expect(operation.entityType == .team)
        #expect(operation.operationType == .create)
        #expect(operation.version == team.version)
        #expect(operation.status == .pending)
        #expect(operation.retryCount == 0)

        let payload = try #require(operation.payload)

        let payloadData = try #require(
            payload.data(using: .utf8)
        )

        let dto = try JSONCoding.decoder.decode(
            TeamDTO.self,
            from: payloadData
        )

        #expect(dto.id == team.id)
        #expect(dto.name == team.name)
        #expect(dto.genre == team.genre)
        #expect(dto.country == team.country)
        #expect(dto.city == team.city)
        #expect(dto.createdAt == team.createdAt)
        #expect(dto.version == team.version)
    }

    // MARK: - Update

    @Test
    func updateTeamPersistsTeamAndCreatesSyncOperation() async throws {

        let (repository, syncOperationRepository, syncScheduler) =
            try makeRepository()

        let team = makeTeam()

        try await repository.createTeam(team)

        let updatedTeam = Team(
            id: team.id,
            name: "Updated Team",
            genre: team.genre,
            country: team.country,
            city: team.city,
            createdAt: team.createdAt,
            version: team.version
        )

        try await repository.updateTeam(updatedTeam)

        #expect(syncScheduler.scheduleSyncCallCount == 2)

        let persistedTeam = try await repository.fetchTeam(
            id: team.id
        )

        let operations = try await syncOperationRepository
            .fetchPendingOperations()

        #expect(persistedTeam.name == "Updated Team")
        #expect(persistedTeam.version == 3)
        #expect(operations.count == 2)

        let updateOperations = operations.filter {
            $0.operationType == .update
        }

        #expect(updateOperations.count == 1)

        let operation = try #require(updateOperations.first)

        #expect(operation.entityID == team.id)
        #expect(operation.entityType == .team)
        #expect(operation.operationType == .update)

        // Expected server base version for the conditional filter.
        #expect(operation.version == team.version)

        #expect(operation.status == .pending)
        #expect(operation.retryCount == 0)

        let payload = try #require(operation.payload)

        let payloadData = try #require(
            payload.data(using: .utf8)
        )

        let dto = try JSONCoding.decoder.decode(
            TeamDTO.self,
            from: payloadData
        )

        #expect(dto.id == updatedTeam.id)
        #expect(dto.name == updatedTeam.name)
        #expect(dto.genre == updatedTeam.genre)
        #expect(dto.country == updatedTeam.country)
        #expect(dto.city == updatedTeam.city)
        #expect(dto.createdAt == updatedTeam.createdAt)
        // Payload carries the local post-update version.
        #expect(dto.version == team.version + 1)
    }

    // MARK: - Delete

    @Test
    func deleteTeamDeletesTeamAndCreatesSyncOperation() async throws {

        let (repository, syncOperationRepository, syncScheduler) =
            try makeRepository()

        let team = makeTeam()

        try await repository.createTeam(team)

        try await repository.deleteTeam(id: team.id)

        #expect(syncScheduler.scheduleSyncCallCount == 2)

        await #expect(throws: RepositoryError.notFound) {
            try await repository.fetchTeam(id: team.id)
        }

        let operations = try await syncOperationRepository
            .fetchPendingOperations()

        #expect(operations.count == 2)

        let deleteOperations = operations.filter {
            $0.operationType == .delete
        }

        #expect(deleteOperations.count == 1)

        let operation = try #require(deleteOperations.first)

        #expect(operation.entityID == team.id)
        #expect(operation.entityType == .team)
        #expect(operation.operationType == .delete)

        // Delete is based on the version that existed before deletion.
        #expect(operation.version == team.version)

        #expect(operation.status == .pending)
        #expect(operation.retryCount == 0)
        #expect(operation.payload == nil)
    }

    // MARK: - Unresolved sync issues

    @Test(arguments: [SyncOperationStatus.conflict, SyncOperationStatus.failed])
    func updateTeamIsRejectedWhileAnUnresolvedOperationExists(
        status: SyncOperationStatus
    ) async throws {

        let blocked = try await makeBlockedTeam(status: status)
        let scheduleCount = blocked.syncScheduler.scheduleSyncCallCount

        await #expect(throws: RepositoryError.unresolvedSyncIssue) {
            try await blocked.repository.updateTeam(
                edited(blocked.team, name: "Second Edit")
            )
        }

        let persisted = try await blocked.repository.fetchTeam(
            id: blocked.team.id
        )

        #expect(persisted.name == "First Edit")
        #expect(persisted.version == blocked.team.version)

        let operations = try await blocked.syncOperationRepository
            .fetchOperations(forEntityID: blocked.team.id)

        // The blocking operation is kept exactly as it was, and nothing new
        // is queued.
        #expect(operations.count == 2)
        #expect(operations.contains(blocked.blockedOperation))
        #expect(blocked.syncScheduler.scheduleSyncCallCount == scheduleCount)
    }

    @Test(arguments: [SyncOperationStatus.conflict, SyncOperationStatus.failed])
    func deleteTeamIsRejectedWhileAnUnresolvedOperationExists(
        status: SyncOperationStatus
    ) async throws {

        let blocked = try await makeBlockedTeam(status: status)
        let scheduleCount = blocked.syncScheduler.scheduleSyncCallCount

        await #expect(throws: RepositoryError.unresolvedSyncIssue) {
            try await blocked.repository.deleteTeam(id: blocked.team.id)
        }

        let persisted = try await blocked.repository.fetchTeam(
            id: blocked.team.id
        )

        #expect(persisted.version == blocked.team.version)

        let operations = try await blocked.syncOperationRepository
            .fetchOperations(forEntityID: blocked.team.id)

        #expect(operations.count == 2)
        #expect(operations.contains(blocked.blockedOperation))
        #expect(blocked.syncScheduler.scheduleSyncCallCount == scheduleCount)
    }

    @Test
    func unresolvedOperationOnOneTeamDoesNotBlockAnother() async throws {

        let blocked = try await makeBlockedTeam(status: .conflict)

        let other = makeTeam()
        let otherEntity = Team(id: UUID(), name: "Other", genre: other.genre, country: other.country, city: other.city, createdAt: other.createdAt, version: other.version)

        try await blocked.repository.createTeam(otherEntity)
        try await blocked.repository.updateTeam(
            edited(otherEntity, name: "Other Edit")
        )

        let persisted = try await blocked.repository.fetchTeam(
            id: otherEntity.id
        )

        #expect(persisted.name == "Other Edit")
    }

    @Test
    func updateTeamWorksAgainOnceTheBlockingOperationIsRemoved() async throws {

        let blocked = try await makeBlockedTeam(status: .conflict)

        // Part B will remove operations through an explicit user action. The
        // test removes it directly only to show the guard is not sticky.
        try await blocked.syncOperationRepository.delete(
            blocked.blockedOperation
        )

        try await blocked.repository.updateTeam(
            edited(blocked.team, name: "Second Edit")
        )

        let persisted = try await blocked.repository.fetchTeam(
            id: blocked.team.id
        )

        #expect(persisted.name == "Second Edit")
        #expect(persisted.version == blocked.team.version + 1)
    }

    // MARK: - Helpers

    private func makeRepository() throws -> (
        repository: SyncTrackingTeamRepository,
        syncOperationRepository: SwiftDataSyncOperationRepository,
        syncScheduler: MockSyncScheduler
    ) {

        let schema = Schema([
            TeamEntity.self,
            SyncOperationEntity.self
        ])

        let configuration = ModelConfiguration(
            isStoredInMemoryOnly: true
        )

        let container = try ModelContainer(
            for: schema,
            configurations: configuration
        )

        let modelContext = ModelContext(container)

        let teamRepository = SwiftDataTeamRepository(
            modelContext: modelContext
        )

        let syncOperationRepository =
            SwiftDataSyncOperationRepository(
                modelContext: modelContext
            )

        let syncScheduler = MockSyncScheduler()

        let repository = SyncTrackingTeamRepository(
            teamRepository: teamRepository,
            syncOperationRepository: syncOperationRepository,
            modelContext: modelContext,
            syncScheduler: syncScheduler
        )

        return (
            repository,
            syncOperationRepository,
            syncScheduler
        )
    }

    private func makeBlockedTeam(
        status: SyncOperationStatus
    ) async throws -> (
        repository: SyncTrackingTeamRepository,
        syncOperationRepository: SwiftDataSyncOperationRepository,
        syncScheduler: MockSyncScheduler,
        team: Team,
        blockedOperation: SyncOperation
    ) {

        let (repository, syncOperationRepository, syncScheduler) =
            try makeRepository()

        let created = makeTeam()

        try await repository.createTeam(created)
        try await repository.updateTeam(
            edited(created, name: "First Edit")
        )

        let pending = try await syncOperationRepository
            .fetchPendingOperations()

        let updateOperation = pending.first {
            $0.operationType == .update
        }

        var blockedOperation = try #require(updateOperation)

        blockedOperation.status = status

        try await syncOperationRepository.update(blockedOperation)

        let current = try await repository.fetchTeam(id: created.id)

        return (
            repository,
            syncOperationRepository,
            syncScheduler,
            current,
            blockedOperation
        )
    }

    private func edited(_ team: Team, name: String) -> Team {

        Team(
            id: team.id,
            name: name,
            genre: team.genre,
            country: team.country,
            city: team.city,
            createdAt: team.createdAt,
            version: team.version
        )
    }

    private func makeTeam() -> Team {

        Team(
            id: UUID(),
            name: "Test Team",
            genre: "Rock",
            country: "Azerbaijan",
            city: "Baku",
            createdAt: Date(timeIntervalSince1970: 900),
            version: 2
        )
    }
}
