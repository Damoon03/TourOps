//
//  ShowRepositoryProtocol.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import Foundation

protocol ShowRepositoryProtocol {
func fetchShows() async throws -> [Show]
func fetchShow(id: UUID) async throws -> Show
func createShow(_ show: Show) async throws
func updateShow(_ show: Show) async throws
func deleteShow(id: UUID) async throws
}
