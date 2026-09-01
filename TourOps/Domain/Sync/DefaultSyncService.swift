//
//  DefaultSyncService.swift
//  TourOps
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation

@MainActor
final class DefaultSyncService: SyncServiceProtocol {

    func execute(
        _ operation: SyncOperation
    ) async throws {

        // Remote execution will be implemented
        // after APIClient is introduced.

        return
    }
}
