//
//  ShowPullServiceProtocol.swift
//  TourOps
//
//  Created by Damoon saber on 7/14/1405 AP.
//

import Foundation

protocol ShowPullServiceProtocol {
    /// Returns the complete remote collection or throws.
    ///
    /// Reconciliation treats a local show that is missing from the result as
    /// deleted remotely, so an implementation must never return a partial or
    /// unverified list.
    func fetchShows() async throws -> [Show]
}
