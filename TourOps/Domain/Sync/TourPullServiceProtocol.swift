//
//  TourPullServiceProtocol.swift
//  TourOps
//
//  Created by Damoon saber on 7/13/1405 AP.
//

import Foundation

protocol TourPullServiceProtocol {
    /// Returns the complete remote collection or throws.
    ///
    /// Reconciliation treats a local tour that is missing from the result as
    /// deleted remotely, so an implementation must never return a partial or
    /// unverified list.
    func fetchTours() async throws -> [Tour]
}
