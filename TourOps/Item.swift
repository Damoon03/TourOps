//
//  Item.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
