//
//  ShowEntity.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import Foundation
import SwiftData

@Model
final class ShowEntity {
@Attribute(.unique) var id: UUID

var tourID: UUID
var name: String
var venue: String
var city: String
var date: Date
var createdAt: Date

init(
    id: UUID,
    tourID: UUID,
    name: String,
    venue: String,
    city: String,
    date: Date,
    createdAt: Date
) {
    self.id = id
    self.tourID = tourID
    self.name = name
    self.venue = venue
    self.city = city
    self.date = date
    self.createdAt = createdAt
}
}

extension ShowEntity {

convenience init(show: Show) {
    self.init(
        id: show.id,
        tourID: show.tourID,
        name: show.name,
        venue: show.venue,
        city: show.city,
        date: show.date,
        createdAt: show.createdAt
    )
}

func toDomain() -> Show {
    Show(
        id: id,
        tourID: tourID,
        name: name,
        venue: venue,
        city: city,
        date: date,
        createdAt: createdAt
    )
}
}
