//
//  TourMapper.swift
//  TourOps
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation

enum TourMapper {

    static func toDTO(
        _ tour: Tour
    ) -> TourDTO {

        TourDTO(
            id: tour.id,
            teamID: tour.teamID,
            name: tour.name,
            startDate: tour.startDate,
            endDate: tour.endDate,
            createdAt: tour.createdAt
        )
    }


    static func toDomain(
        _ dto: TourDTO
    ) -> Tour {

        Tour(
            id: dto.id,
            teamID: dto.teamID,
            name: dto.name,
            startDate: dto.startDate,
            endDate: dto.endDate,
            createdAt: dto.createdAt
        )
    }
}
