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
        let (repository, syncOperationRepository) = try makeRepository()
        let team = makeTeam()

        try await repository.createTeam(team)

        let persistedTeam = try await repository.fetchTeam(id: team.id)
        let operations = try await syncOperationRepository.fetchPendingOperations()

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

        let dto = try JSONDecoder().decode(
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
        let (repository, syncOperationRepository) = try makeRepository()
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

        let persistedTeam = try await repository.fetchTeam(id: team.id)
        let operations = try await syncOperationRepository.fetchPendingOperations()

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

        // The operation is based on version 2.
        #expect(operation.version == team.version)

        #expect(operation.status == .pending)
        #expect(operation.retryCount == 0)

        let payload = try #require(operation.payload)

        let payloadData = try #require(
            payload.data(using: .utf8)
        )

        let dto = try JSONDecoder().decode(
            TeamDTO.self,
            from: payloadData
        )

        #expect(dto.id == updatedTeam.id)
        #expect(dto.name == updatedTeam.name)
        #expect(dto.genre == updatedTeam.genre)
        #expect(dto.country == updatedTeam.country)
        #expect(dto.city == updatedTeam.city)
        #expect(dto.createdAt == updatedTeam.createdAt)
        #expect(dto.version == updatedTeam.version)
    }

    // MARK: - Delete

    @Test
    func deleteTeamDeletesTeamAndCreatesSyncOperation() async throws {
        let (repository, syncOperationRepository) = try makeRepository()
        let team = makeTeam()

        try await repository.createTeam(team)
        try await repository.deleteTeam(id: team.id)

        await #expect(throws: RepositoryError.notFound) {
            try await repository.fetchTeam(id: team.id)
        }

        let operations = try await syncOperationRepository.fetchPendingOperations()

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

    // MARK: - Helpers

    private func makeRepository() throws -> (
        repository: SyncTrackingTeamRepository,
        syncOperationRepository: SwiftDataSyncOperationRepository
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

        let syncOperationRepository = SwiftDataSyncOperationRepository(
            modelContext: modelContext
        )

        let repository = SyncTrackingTeamRepository(
            teamRepository: teamRepository,
            syncOperationRepository: syncOperationRepository,
            modelContext: modelContext
        )

        return (
            repository,
            syncOperationRepository
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
