//
//  TourOpsApp.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import SwiftUI

@main
struct TourOpsApp: App {

    private let teamRepository = MockTeamRepository()

    var body: some Scene {
        WindowGroup {
            TeamListView(repository: teamRepository)
        }
    }
}
