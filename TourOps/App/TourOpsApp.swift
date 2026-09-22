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
    private let syncScheduler: SyncScheduler

    init() {
        do {
            let schema = Schema([
                TeamEntity.self,
                TourEntity.self,
                ShowEntity.self,
                SyncOperationEntity.self
            ])

            let container = try ModelContainer(
                for: schema
            )
            self.modelContainer = container

            let modelContext = container.mainContext

            let syncOperationRepository =
                SwiftDataSyncOperationRepository(
                    modelContext: modelContext
                )

            let apiClient = APIClient()

            let requestBuilder = SyncRequestBuilder(
                baseURL: TourOpsSupabaseClient.shared.baseURL
            )

            let authService = SupabaseAuthService()

            let syncService = SupabaseSyncService(
                apiClient: apiClient,
                requestBuilder: requestBuilder,
                authService: authService
            )

            let syncEngine = SyncEngine(
                syncOperationRepository: syncOperationRepository,
                syncService: syncService,
                retryPolicy: SyncRetryPolicy(
                    maxRetryCount: 3
                ),
                operationReducer: SyncOperationReducer()
            )

            let syncScheduler = SyncScheduler(
                syncEngine: syncEngine
            )

            self.syncScheduler = syncScheduler

            let teamRepository =
                SwiftDataTeamRepository(
                    modelContext: modelContext
                )

            let tourRepository =
                SwiftDataTourRepository(
                    modelContext: modelContext
                )

            let showRepository =
                SwiftDataShowRepository(
                    modelContext: modelContext
                )

            self.teamRepository =
                SyncTrackingTeamRepository(
                    teamRepository: teamRepository,
                    syncOperationRepository: syncOperationRepository,
                    modelContext: modelContext,
                    syncScheduler: syncScheduler
                )

            self.tourRepository =
                SyncTrackingTourRepository(
                    tourRepository: tourRepository,
                    syncOperationRepository: syncOperationRepository,
                    modelContext: modelContext,
                    syncScheduler: syncScheduler
                )

            self.showRepository =
                SyncTrackingShowRepository(
                    showRepository: showRepository,
                    syncOperationRepository: syncOperationRepository,
                    modelContext: modelContext,
                    syncScheduler: syncScheduler
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
            .task {
                let authService = SupabaseAuthService()

                do {
                    try await authService.signIn(
                        email: "test1@gmail.com",
                        password: "rinmep-kafpAz-dixra8"
                    )

                    let token = try await authService.accessToken()

                    print("Supabase authentication succeeded.")
                    print(
                        "Access token received: \(token.isEmpty == false)"
                    )

                    syncScheduler.scheduleSync()

                } catch {
                    print("Authentication failed:", error)
                }
            }
        }
        .modelContainer(modelContainer)
    }
}

