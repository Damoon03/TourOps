//
//  TeamMapper.swift
//  TourOps
//

import Foundation

enum TeamMapper {
    static func toDTO(_ team: Team) -> TeamDTO {
        TeamDTO(
            id: team.id,
            name: team.name,
            genre: team.genre,
            country: team.country,
            city: team.city,
            createdAt: team.createdAt,
            version: team.version
        )
    }

    static func toDomain(_ dto: TeamDTO) -> Team {
        Team(
            id: dto.id,
            name: dto.name,
            genre: dto.genre,
            country: dto.country,
            city: dto.city,
            createdAt: dto.createdAt,
            version: dto.version
        )
    }
}
