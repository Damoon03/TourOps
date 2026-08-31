//
//  SyncRetryPolicy.swift
//  TourOps
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation

struct SyncRetryPolicy {

    let maxRetryCount: Int

    init(maxRetryCount: Int = 3) {
        self.maxRetryCount = maxRetryCount
    }

    func shouldRetry(_ operation: SyncOperation) -> Bool {
        operation.retryCount < maxRetryCount
    }

    func nextRetryCount(for operation: SyncOperation) -> Int {
        operation.retryCount + 1
    }
}
