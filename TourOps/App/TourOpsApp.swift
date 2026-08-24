//
//  TourOpsApp.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import SwiftUI
import SwiftData

@main
struct TourOpsApp: App {

    private let teamRepository: SwiftDataTeamRepository

    init() {
        do {
            let schema = Schema([
                TeamEntity.self
            ])

            let container = try ModelContainer(for: schema)

            self.teamRepository = SwiftDataTeamRepository(
                modelContext: container.mainContext
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TeamListView(repository: teamRepository)
        }
    }
}
