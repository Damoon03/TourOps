//
//  SwiftDataSyncOperationRepositoryTests.swift
//  TourOpsTests
//
//  Created by Damoon saber on 6/8/1405 AP.
//

import Foundation
import Testing
import SwiftData
@testable import TourOps

@MainActor
struct SwiftDataSyncOperationRepositoryTests {

// MARK: - Add

@Test
func addPersistsOperation() async throws {
    let (repository, _) = try makeRepository()
    let operation = makeOperation()

    try await repository.add(operation)

    let operations = try await repository.fetchPendingOperations()

    #expect(operations.count == 1)
    #expect(operations.first?.id == operation.id)
}

@Test
func addThrowsDuplicateForExistingOperation() async throws {
    let (repository, _) = try makeRepository()
    let operation = makeOperation()

    try await repository.add(operation)

    await #expect(throws: RepositoryError.duplicate) {
        try await repository.add(operation)
    }
}

// MARK: - Fetch

@Test
func fetchPendingOperationsReturnsOnlyPendingOperations() async throws {
    let (repository, _) = try makeRepository()

    let pending = makeOperation(status: .pending)
    let processing = makeOperation(status: .processing)
    let failed = makeOperation(status: .failed)

    try await repository.add(pending)
    try await repository.add(processing)
    try await repository.add(failed)

    let operations = try await repository.fetchPendingOperations()

    #expect(operations.count == 1)
    #expect(operations.first?.id == pending.id)
}

@Test
func fetchPendingOperationsReturnsOperationsInCreationOrder() async throws {
    let (repository, _) = try makeRepository()

    let first = makeOperation(
        createdAt: Date(timeIntervalSince1970: 100)
    )

    let second = makeOperation(
        createdAt: Date(timeIntervalSince1970: 200)
    )

    try await repository.add(second)
    try await repository.add(first)

    let operations = try await repository.fetchPendingOperations()

    #expect(operations.map(\.id) == [first.id, second.id])
}

// MARK: - Update

@Test
func updateChangesPersistedOperation() async throws {
    let (repository, context) = try makeRepository()

    let operation = makeOperation()

    try await repository.add(operation)

    var updatedOperation = operation
    updatedOperation.status = .failed
    updatedOperation.retryCount = 2

    try await repository.update(updatedOperation)

    let descriptor = FetchDescriptor<SyncOperationEntity>()
    let entities = try context.fetch(descriptor)

    #expect(entities.count == 1)
    #expect(
        entities.first?.status ==
        SyncOperationStatus.failed.rawValue
    )
    #expect(entities.first?.retryCount == 2)
}

@Test
func updateThrowsNotFoundForMissingOperation() async throws {
    let (repository, _) = try makeRepository()
    let operation = makeOperation()

    await #expect(throws: RepositoryError.notFound) {
        try await repository.update(operation)
    }
}

// MARK: - Delete

@Test
func deleteRemovesOperation() async throws {
    let (repository, _) = try makeRepository()

    let operation = makeOperation()

    try await repository.add(operation)
    try await repository.delete(operation)

    let operations = try await repository.fetchPendingOperations()

    #expect(operations.isEmpty)
}

@Test
func deleteThrowsNotFoundForMissingOperation() async throws {
    let (repository, _) = try makeRepository()
    let operation = makeOperation()

    await #expect(throws: RepositoryError.notFound) {
        try await repository.delete(operation)
    }
}

// MARK: - Helpers

private func makeRepository() throws -> (
    repository: SwiftDataSyncOperationRepository,
    context: ModelContext
) {
    let schema = Schema([
        SyncOperationEntity.self
    ])

    let configuration = ModelConfiguration(
        isStoredInMemoryOnly: true
    )

    let container = try ModelContainer(
        for: schema,
        configurations: configuration
    )

    let context = ModelContext(container)

    let repository = SwiftDataSyncOperationRepository(
        modelContext: context
    )

    return (repository, context)
}

private func makeOperation(
    status: SyncOperationStatus = .pending,
    createdAt: Date = Date()
) -> SyncOperation {
    SyncOperation(
        id: UUID(),
        entityID: UUID(),
        entityType: .team,
        operationType: .create,
        createdAt: createdAt,
        status: status,
        retryCount: 0
    )
}
    
}
