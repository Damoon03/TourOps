//
//  SyncOperationRepositoryProtocol.swift
//  TourOps
//
//  Created by Damoon saber on 6/7/1405 AP.
//

import Foundation

protocol SyncOperationRepositoryProtocol {

    func fetchPendingOperations() async throws -> [SyncOperation]

    func add(_ operation: SyncOperation) async throws

    func update(_ operation: SyncOperation) async throws

    func delete(_ operation: SyncOperation) async throws
}
