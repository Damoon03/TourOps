//
//  SyncRunResult.swift
//  TourOps
//
//  Created by Damoon saber on 7/27/1405 AP.
//

import Foundation

enum SyncRunResult: Equatable {
    /// At least one operation was actually pushed and no operation failed.
    /// Operations that collapse into no-ops are cleaned up locally and do not
    /// count as a push.
    case success

    /// There were no operations to synchronize.
    case noWork

    /// At least one operation failed or could not be synchronized.
    case failure

    /// The sync run was cancelled.
    case cancelled
}
