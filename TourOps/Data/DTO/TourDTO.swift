//
//  TourDTO.swift
//  TourOps
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation

struct TourDTO: Codable {

    let id: UUID
    let teamID: UUID
    let name: String
    let startDate: Date
    let endDate: Date
    let createdAt: Date
    let version: Int

    enum CodingKeys: String, CodingKey {
        case id
        case teamID = "team_id"
        case name
        case startDate = "start_date"
        case endDate = "end_date"
        case createdAt = "created_at"
        case version
    }
}
