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

    private let modelContainer: ModelContainer
    private let teamRepository: SwiftDataTeamRepository
    private let tourRepository: SwiftDataTourRepository

    init() {
        do {
            let schema = Schema([
                TeamEntity.self,
                TourEntity.self
            ])

            let container = try ModelContainer(for: schema)

            self.modelContainer = container

            self.teamRepository = SwiftDataTeamRepository(
                modelContext: container.mainContext
            )

            self.tourRepository = SwiftDataTourRepository(
                modelContext: container.mainContext
            )
        } catch {
            fatalError(
                "Failed to create ModelContainer: \(error)"
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            TeamListView(
                repository: teamRepository,
                tourRepository: tourRepository
            )
        }
    }
}
