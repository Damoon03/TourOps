//
//  TeamRepositoryProtocol.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import Foundation

protocol TeamRepositoryProtocol {
    func fetchTeams() async throws -> [Team]
    func fetchTeam(id: UUID) async throws -> Team
    func createTeam(_ team: Team) async throws
    func updateTeam(_ team: Team) async throws
    func deleteTeam(id: UUID) async throws
}
