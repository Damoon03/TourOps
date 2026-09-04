//
//  Show.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import Foundation

struct Show: Identifiable, Equatable {
    let id: UUID
    let tourID: UUID
    let name: String
    let venue: String
    let city: String
    let date: Date
    let createdAt: Date
    let version: Int
}
