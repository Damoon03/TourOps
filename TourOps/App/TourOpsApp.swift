//
//  TourOpsApp.swift
//  TourOps
//
//  Created by Damoon saber on 6/7/1405 AP.
//

import SwiftUI
import SwiftData

@main
struct TourOpsApp: App {

private let modelContainer: ModelContainer

private let teamRepository: SyncTrackingTeamRepository
private let tourRepository: SyncTrackingTourRepository
private let showRepository: SyncTrackingShowRepository

init() {

    do {

        let schema = Schema([
            TeamEntity.self,
            TourEntity.self,
            ShowEntity.self,
            SyncOperationEntity.self
        ])

        let container = try ModelContainer(for: schema)

        self.modelContainer = container

        let modelContext = container.mainContext

        let syncOperationRepository = SwiftDataSyncOperationRepository(
            modelContext: modelContext
        )

        let teamRepository = SwiftDataTeamRepository(
            modelContext: modelContext
        )

        let tourRepository = SwiftDataTourRepository(
            modelContext: modelContext
        )

        let showRepository = SwiftDataShowRepository(
            modelContext: modelContext
        )

        self.teamRepository = SyncTrackingTeamRepository(
            teamRepository: teamRepository,
            syncOperationRepository: syncOperationRepository,
            modelContext: modelContext
        )

        self.tourRepository = SyncTrackingTourRepository(
            tourRepository: tourRepository,
            syncOperationRepository: syncOperationRepository,
            modelContext: modelContext
        )

        self.showRepository = SyncTrackingShowRepository(
            showRepository: showRepository,
            syncOperationRepository: syncOperationRepository,
            modelContext: modelContext
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
            tourRepository: tourRepository,
            showRepository: showRepository
        )
    }
    .modelContainer(modelContainer)
}
}
