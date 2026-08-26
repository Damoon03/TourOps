//
//  TourRepositoryProtocol.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import Foundation

protocol TourRepositoryProtocol {

    func fetchTours() async throws -> [Tour]

    func fetchTour(id: UUID) async throws -> Tour

    func createTour(_ tour: Tour) async throws

    func updateTour(_ tour: Tour) async throws

    func deleteTour(id: UUID) async throws
}
