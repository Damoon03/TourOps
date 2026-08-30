//
//  SyncTrackingTeamRepository.swift
//  TourOps
//
//  Created by Damoon saber on 9/6/1405 AP.
//

import Foundation
import SwiftData

@MainActor
final class SyncTrackingTeamRepository: TeamRepositoryProtocol {

private let teamRepository: SwiftDataTeamRepository
private let syncOperationRepository: SwiftDataSyncOperationRepository
private let modelContext: ModelContext

init(
    teamRepository: SwiftDataTeamRepository,
    syncOperationRepository: SwiftDataSyncOperationRepository,
    modelContext: ModelContext
) {
    self.teamRepository = teamRepository
    self.syncOperationRepository = syncOperationRepository
    self.modelContext = modelContext
}

// MARK: - Fetch

func fetchTeams() async throws -> [Team] {
    try await teamRepository.fetchTeams()
}

func fetchTeam(id: UUID) async throws -> Team {
    try await teamRepository.fetchTeam(id: id)
}

// MARK: - Create

func createTeam(_ team: Team) async throws {
    try teamRepository.stageCreateTeam(team)

    let operation = SyncOperation(
        id: UUID(),
        entityID: team.id,
        entityType: .team,
        operationType: .create,
        createdAt: Date(),
        status: .pending,
        retryCount: 0
    )

    try syncOperationRepository.stageAdd(operation)

    try modelContext.save()
}

// MARK: - Update

func updateTeam(_ team: Team) async throws {
    try teamRepository.stageUpdateTeam(team)

    let operation = SyncOperation(
        id: UUID(),
        entityID: team.id,
        entityType: .team,
        operationType: .update,
        createdAt: Date(),
        status: .pending,
        retryCount: 0
    )

    try syncOperationRepository.stageAdd(operation)

    try modelContext.save()
}

// MARK: - Delete

func deleteTeam(id: UUID) async throws {
    try teamRepository.stageDeleteTeam(id: id)

    let operation = SyncOperation(
        id: UUID(),
        entityID: id,
        entityType: .team,
        operationType: .delete,
        createdAt: Date(),
        status: .pending,
        retryCount: 0
    )

    try syncOperationRepository.stageAdd(operation)

    try modelContext.save()
}
}
