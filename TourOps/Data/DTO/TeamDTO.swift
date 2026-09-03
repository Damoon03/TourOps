//
//  TeamDTO.swift
//  TourOps
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation

struct TeamDTO: Codable {

    let id: UUID
    let name: String
    let genre: String
    let country: String
    let city: String
    let createdAt: Date
}
