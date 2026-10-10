//
//  DataRefreshSignal.swift
//  TourOps
//
//  Created by Damoon saber on 7/18/1405 AP.
//

import Observation

@MainActor
@Observable
final class DataRefreshSignal {
    private(set) var generation = 0

    func bump() {
        generation += 1
    }
}
