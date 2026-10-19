//
//  SyncRunResult.swift
//  TourOps
//
//  Created by Damoon saber on 7/27/1405 AP.
//

import Foundation

enum SyncRunResult: Equatable {
    /// All operations in this sync run completed successfully.
    case success

    /// There were no operations to synchronize.
    case noWork

    /// At least one operation failed or could not be synchronized.
    case failure

    /// The sync run was cancelled.
    case cancelled
}
