//
//  TeamPullServiceProtocol.swift
//  TourOps
//
//  Created by Damoon saber on 7/9/1405 AP.
//

import Foundation

protocol TeamPullServiceProtocol {
    func fetchTeams() async throws -> [Team]
}
