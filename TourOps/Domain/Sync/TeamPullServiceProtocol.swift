//
//  TeamPullServiceProtocol.swift
//  TourOps
//
//  Created by Damoon saber on 7/9/1405 AP.
//

import Foundation

protocol TeamPullServiceProtocol {
    /// Returns the complete remote collection or throws.
    ///
    /// Reconciliation treats a local team that is missing from the result as
    /// deleted remotely, so an implementation must never return a partial or
    /// unverified list.
    func fetchTeams() async throws -> [Team]
}
