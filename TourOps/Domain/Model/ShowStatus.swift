//
//  ShowStatus.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import Foundation
enum ShowStatus: String, Codable, CaseIterable {
    case scheduled
    case confirmed
    case inProgress
    case completed
    case cancelled
}
