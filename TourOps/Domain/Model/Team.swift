//
//  Team.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import Foundation

struct Team: Identifiable, Equatable {
    let id: UUID
    let name: String
    let genre: String
    let country: String
    let city: String
    let createdAt: Date
}
