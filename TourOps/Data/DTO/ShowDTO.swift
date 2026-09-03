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
}
