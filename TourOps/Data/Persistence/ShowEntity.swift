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
    var version: Int = 1
    init(
        id: UUID,
        tourID: UUID,
        name: String,
        venue: String,
        city: String,
        date: Date,
        createdAt: Date,
        version: Int
    ) {
        self.id = id
        self.tourID = tourID
        self.name = name
        self.venue = venue
        self.city = city
        self.date = date
        self.createdAt = createdAt
        self.version = version
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
            createdAt: show.createdAt,
            version: show.version
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
            createdAt: createdAt,
            version: version
        )
    }
}
