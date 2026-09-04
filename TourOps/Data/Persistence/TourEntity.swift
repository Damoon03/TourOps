//
//  TourEntity.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import Foundation
import SwiftData

@Model
final class TourEntity {
    @Attribute(.unique) var id: UUID
    var teamID: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var version: Int = 1
    init(
        id: UUID,
        teamID: UUID,
        name: String,
        startDate: Date,
        endDate: Date,
        createdAt: Date,
        version: Int
    ) {
        self.id = id
        self.teamID = teamID
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
        self.version = version
    }
}

extension TourEntity {
    convenience init(tour: Tour) {
        self.init(
            id: tour.id,
            teamID: tour.teamID,
            name: tour.name,
            startDate: tour.startDate,
            endDate: tour.endDate,
            createdAt: tour.createdAt,
            version: tour.version
        )
    }

    func toDomain() -> Tour {
        Tour(
            id: id,
            teamID: teamID,
            name: name,
            startDate: startDate,
            endDate: endDate,
            createdAt: createdAt,
            version: version
        )
    }
}
