//
//  TeamEntity.swift
//  TourOps
//
//  Created by Damoon saber on 6/1/1405 AP.
//

import Foundation
import SwiftData

@Model
final class TeamEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var genre: String
    var country: String
    var city: String
    var createdAt: Date
    var version: Int = 1
    init(
        id: UUID,
        name: String,
        genre: String,
        country: String,
        city: String,
        createdAt: Date,
        version: Int
    ) {
        self.id = id
        self.name = name
        self.genre = genre
        self.country = country
        self.city = city
        self.createdAt = createdAt
        self.version = version
    }
}

extension TeamEntity {
    convenience init(team: Team) {
        self.init(
            id: team.id,
            name: team.name,
            genre: team.genre,
            country: team.country,
            city: team.city,
            createdAt: team.createdAt,
            version: team.version
        )
    }

    func toDomain() -> Team {
        Team(
            id: id,
            name: name,
            genre: genre,
            country: country,
            city: city,
            createdAt: createdAt,
            version: version
        )
    }
}
