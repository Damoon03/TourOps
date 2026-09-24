//
//  ShowDTO.swift
//  TourOps
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation

struct ShowDTO: Codable {

    let id: UUID
    let tourID: UUID
    let name: String
    let venue: String
    let city: String
    let date: Date
    let createdAt: Date
    let version: Int

    enum CodingKeys: String, CodingKey {
        case id
        case tourID = "tour_id"
        case name
        case venue
        case city
        case date
        case createdAt = "created_at"
        case version
    }
}
