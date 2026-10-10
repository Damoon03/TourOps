//
//  TourOpsApp.swift
//  TourOps
//
//  Created by Damoon saber on 6/7/1405 AP.
//

import SwiftUI
import SwiftData
import os

@main
struct TourOpsApp: App {

    private static let pullLogger = Logger(
        subsystem: "com.tourops.app",
        category: "PullSync"
    )

    @Environment(\.scenePhase) private var scenePhase

    private let modelContainer: ModelContainer
    private let teamRepository: SyncTrackingTeamRepository
    private let tourRepository: SyncTrackingTourRepository
    private let showRepository: SyncTrackingShowRepository
    private let syncScheduler: SyncScheduler
    private let teamPullCoordinator: TeamPullCoordinator
    private let tourPullCoordinator: TourPullCoordinator
    private let authSessionController: AuthSessionController
    private let showPullCoordinator: ShowPullCoordinator
    private let refreshSignal: DataRefreshSignal

    init() {

        self.refreshSignal = DataRefreshSignal()

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

            let authSessionController = AuthSessionController()

            self.authSessionController = authSessionController

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

            let teamPullService = SupabaseTeamPullService(
                apiClient: apiClient,
                authService: authService,
                baseURL: TourOpsSupabaseClient.shared.baseURL
            )

            let teamReconciler = TeamReconciler(
                teamRepository: teamRepository,
                syncOperationRepository: syncOperationRepository
            )

            self.teamPullCoordinator = TeamPullCoordinator(
                pullService: teamPullService,
                reconciler: teamReconciler
            )

            let tourPullService = SupabaseTourPullService(
                apiClient: apiClient,
                authService: authService,
                baseURL: TourOpsSupabaseClient.shared.baseURL
            )

            let tourReconciler = TourReconciler(
                tourRepository: tourRepository,
                syncOperationRepository: syncOperationRepository
            )

            self.tourPullCoordinator = TourPullCoordinator(
                pullService: tourPullService,
                reconciler: tourReconciler
            )

            let showPullService = SupabaseShowPullService(
                apiClient: apiClient,
                authService: authService,
                baseURL: TourOpsSupabaseClient.shared.baseURL
            )

            let showReconciler = ShowReconciler(
                showRepository: showRepository,
                syncOperationRepository: syncOperationRepository
            )

            self.showPullCoordinator = ShowPullCoordinator(
                pullService: showPullService,
                reconciler: showReconciler
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

            Group {

                switch authSessionController.state {

                case .loading:
                    ProgressView()

                case .signedOut:
                    LoginView()

                case .signedIn:
                    TeamListView(
                        repository: teamRepository,
                        tourRepository: tourRepository,
                        showRepository: showRepository
                    )
                }
            }
            .environment(refreshSignal)
            .task {
                await authSessionController.start()
            }
            .onChange(of: authSessionController.state) { _, newState in

                if newState == .signedIn {
                    Task {
                        await runPushAndPull()
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in

                if newPhase == .active {
                    Task {
                        await runPushAndPull()
                    }
                }
            }
        }
        .modelContainer(modelContainer)
    }

    private func runPushAndPull() async {
        await syncScheduler.syncNow()

        var didAnyPullSucceed = false

        do {
            try await teamPullCoordinator.pullTeams()
            didAnyPullSucceed = true
        } catch {
            Self.pullLogger.error("Team pull failed: \(error.localizedDescription, privacy: .public)")
        }

        do {
            try await tourPullCoordinator.pullTours()
            didAnyPullSucceed = true
        } catch {
            Self.pullLogger.error("Tour pull failed: \(error.localizedDescription, privacy: .public)")
        }

        do {
            try await showPullCoordinator.pullShows()
            didAnyPullSucceed = true
        } catch {
            Self.pullLogger.error("Show pull failed: \(error.localizedDescription, privacy: .public)")
        }

        if didAnyPullSucceed {
            refreshSignal.bump()
        }
    }
}
