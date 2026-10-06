//
//  ShowPullServiceProtocol.swift
//  TourOps
//
//  Created by Damoon saber on 7/14/1405 AP.
//

import Foundation

protocol ShowPullServiceProtocol {
    func fetchShows() async throws -> [Show]
}
