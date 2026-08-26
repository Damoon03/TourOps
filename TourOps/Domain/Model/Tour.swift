//
//  Tour.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import Foundation

struct Tour: Identifiable, Equatable {

    let id: UUID
    let teamID: UUID
    let name: String
    let startDate: Date
    let endDate: Date
    let createdAt: Date
}
