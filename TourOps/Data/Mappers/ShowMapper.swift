//
//  ShowMapper.swift
//  TourOps
//

import Foundation

enum ShowMapper {
    static func toDTO(_ show: Show) -> ShowDTO {
        ShowDTO(
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

    static func toDomain(_ dto: ShowDTO) -> Show {
        Show(
            id: dto.id,
            tourID: dto.tourID,
            name: dto.name,
            venue: dto.venue,
            city: dto.city,
            date: dto.date,
            createdAt: dto.createdAt,
            version: dto.version
        )
    }
}
