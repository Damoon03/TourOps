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
    
    @Environment(\.scenePhase) private var scenePhase
    
    private let modelContainer: ModelContainer
    private let teamRepository: SyncTrackingTeamRepository
    private let tourRepository: SyncTrackingTourRepository
    private let showRepository: SyncTrackingShowRepository
    private let syncScheduler: SyncScheduler
    private let teamPullCoordinator: TeamPullCoordinator
    private let authSessionController: AuthSessionController
    
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
            .task {
                await authSessionController.start()
            }
            .onChange(of: authSessionController.state) { _, newState in
                if newState == .signedIn {
                    Task {
                        await syncScheduler.syncNow()
                        try? await teamPullCoordinator.pullTeams()
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await syncScheduler.syncNow()
                        try? await teamPullCoordinator.pullTeams()
                    }
                }
            }
        }
        .modelContainer(modelContainer)
    }
}

