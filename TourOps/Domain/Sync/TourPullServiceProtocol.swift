//
//  TourPullServiceProtocol.swift
//  TourOps
//
//  Created by Damoon saber on 7/13/1405 AP.
//

import Foundation

protocol TourPullServiceProtocol {
    func fetchTours() async throws -> [Tour]
}
