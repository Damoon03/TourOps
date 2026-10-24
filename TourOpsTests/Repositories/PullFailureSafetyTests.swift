import Foundation
import SwiftData
import Testing
@testable import TourOps

/// Verifies at the coordinator boundary that a failed or unverified pull
/// leaves local data untouched. Two kinds of failure are covered for each
/// entity: a pull service that throws, and the real Supabase pull service,
/// coordinator and reconciler fed a response that would delete local
/// records if it reached the reconciler.
@MainActor
struct PullFailureSafetyTests {

    // MARK: - Teams

    @Test
    func teamPullServiceFailureLeavesLocalTeamsUntouched() async throws {
        let context = container.mainContext
        let repository = SwiftDataTeamRepository(modelContext: context)
        let seeded = makeTeams()

        for team in seeded {
            try await repository.createTeam(team)
        }

        let coordinator = TeamPullCoordinator(
            pullService: FailingTeamPullService(),
            reconciler: makeTeamReconciler(repository, context)
        )

        let error = await capturedError {
            try await coordinator.pullTeams()
        }

        #expect(error as? PullTestError == .failed)
        #expect(byID(try await repository.fetchTeams()) == byID(seeded))
    }

    @Test
    func teamPullWithoutPaginationMetadataLeavesLocalTeamsUntouched() async throws {
        let context = container.mainContext
        let repository = SwiftDataTeamRepository(modelContext: context)
        let seeded = makeTeams()

        for team in seeded {
            try await repository.createTeam(team)
        }

        // One of three remote teams and no Content-Range: a non-empty
        // partial list that would delete the other two local teams.
        let client = try FixedResponseAPIClient(
            rows: [TeamMapper.toDTO(seeded[0])],
            contentRange: nil
        )

        let coordinator = TeamPullCoordinator(
            pullService: SupabaseTeamPullService(
                apiClient: client,
                authService: PullTestAuthService(),
                baseURL: testBaseURL
            ),
            reconciler: makeTeamReconciler(repository, context)
        )

        let error = await capturedError {
            try await coordinator.pullTeams()
        }

        #expect(error as? SupabasePaginationError == .missingContentRange)
        #expect(byID(try await repository.fetchTeams()) == byID(seeded))
    }

    @Test
    func teamPullWithTruncatedPageLeavesLocalTeamsUntouched() async throws {
        let context = container.mainContext
        let repository = SwiftDataTeamRepository(modelContext: context)
        let seeded = makeTeams()

        for team in seeded {
            try await repository.createTeam(team)
        }

        // The header claims three rows but the body holds one.
        let client = try FixedResponseAPIClient(
            rows: [TeamMapper.toDTO(seeded[0])],
            contentRange: "0-2/3"
        )

        let coordinator = TeamPullCoordinator(
            pullService: SupabaseTeamPullService(
                apiClient: client,
                authService: PullTestAuthService(),
                baseURL: testBaseURL
            ),
            reconciler: makeTeamReconciler(repository, context)
        )

        let error = await capturedError {
            try await coordinator.pullTeams()
        }

        #expect(
            error as? SupabasePaginationError
            == .responseCountMismatch(expected: 3, actual: 1)
        )
        #expect(byID(try await repository.fetchTeams()) == byID(seeded))
    }

    // MARK: - Tours

    @Test
    func tourPullServiceFailureLeavesLocalToursUntouched() async throws {
        let context = container.mainContext
        let repository = SwiftDataTourRepository(modelContext: context)
        let seeded = makeTours()

        for tour in seeded {
            try await repository.createTour(tour)
        }

        let coordinator = TourPullCoordinator(
            pullService: FailingTourPullService(),
            reconciler: makeTourReconciler(repository, context)
        )

        let error = await capturedError {
            try await coordinator.pullTours()
        }

        #expect(error as? PullTestError == .failed)
        #expect(byID(try await repository.fetchTours()) == byID(seeded))
    }

    @Test
    func tourPullWithoutPaginationMetadataLeavesLocalToursUntouched() async throws {
        let context = container.mainContext
        let repository = SwiftDataTourRepository(modelContext: context)
        let seeded = makeTours()

        for tour in seeded {
            try await repository.createTour(tour)
        }

        let client = try FixedResponseAPIClient(
            rows: [TourMapper.toDTO(seeded[0])],
            contentRange: nil
        )

        let coordinator = TourPullCoordinator(
            pullService: SupabaseTourPullService(
                apiClient: client,
                authService: PullTestAuthService(),
                baseURL: testBaseURL
            ),
            reconciler: makeTourReconciler(repository, context)
        )

        let error = await capturedError {
            try await coordinator.pullTours()
        }

        #expect(error as? SupabasePaginationError == .missingContentRange)
        #expect(byID(try await repository.fetchTours()) == byID(seeded))
    }

    @Test
    func tourPullWithTruncatedPageLeavesLocalToursUntouched() async throws {
        let context = container.mainContext
        let repository = SwiftDataTourRepository(modelContext: context)
        let seeded = makeTours()

        for tour in seeded {
            try await repository.createTour(tour)
        }

        let client = try FixedResponseAPIClient(
            rows: [TourMapper.toDTO(seeded[0])],
            contentRange: "0-2/3"
        )

        let coordinator = TourPullCoordinator(
            pullService: SupabaseTourPullService(
                apiClient: client,
                authService: PullTestAuthService(),
                baseURL: testBaseURL
            ),
            reconciler: makeTourReconciler(repository, context)
        )

        let error = await capturedError {
            try await coordinator.pullTours()
        }

        #expect(
            error as? SupabasePaginationError
            == .responseCountMismatch(expected: 3, actual: 1)
        )
        #expect(byID(try await repository.fetchTours()) == byID(seeded))
    }

    // MARK: - Shows

    @Test
    func showPullServiceFailureLeavesLocalShowsUntouched() async throws {
        let context = container.mainContext
        let repository = SwiftDataShowRepository(modelContext: context)
        let seeded = makeShows()

        for show in seeded {
            try await repository.createShow(show)
        }

        let coordinator = ShowPullCoordinator(
            pullService: FailingShowPullService(),
            reconciler: makeShowReconciler(repository, context)
        )

        let error = await capturedError {
            try await coordinator.pullShows()
        }

        #expect(error as? PullTestError == .failed)
        #expect(byID(try await repository.fetchShows()) == byID(seeded))
    }

    @Test
    func showPullWithoutPaginationMetadataLeavesLocalShowsUntouched() async throws {
        let context = container.mainContext
        let repository = SwiftDataShowRepository(modelContext: context)
        let seeded = makeShows()

        for show in seeded {
            try await repository.createShow(show)
        }

        let client = try FixedResponseAPIClient(
            rows: [ShowMapper.toDTO(seeded[0])],
            contentRange: nil
        )

        let coordinator = ShowPullCoordinator(
            pullService: SupabaseShowPullService(
                apiClient: client,
                authService: PullTestAuthService(),
                baseURL: testBaseURL
            ),
            reconciler: makeShowReconciler(repository, context)
        )

        let error = await capturedError {
            try await coordinator.pullShows()
        }

        #expect(error as? SupabasePaginationError == .missingContentRange)
        #expect(byID(try await repository.fetchShows()) == byID(seeded))
    }

    @Test
    func showPullWithTruncatedPageLeavesLocalShowsUntouched() async throws {
        let context = container.mainContext
        let repository = SwiftDataShowRepository(modelContext: context)
        let seeded = makeShows()

        for show in seeded {
            try await repository.createShow(show)
        }

        let client = try FixedResponseAPIClient(
            rows: [ShowMapper.toDTO(seeded[0])],
            contentRange: "0-2/3"
        )

        let coordinator = ShowPullCoordinator(
            pullService: SupabaseShowPullService(
                apiClient: client,
                authService: PullTestAuthService(),
                baseURL: testBaseURL
            ),
            reconciler: makeShowReconciler(repository, context)
        )

        let error = await capturedError {
            try await coordinator.pullShows()
        }

        #expect(
            error as? SupabasePaginationError
            == .responseCountMismatch(expected: 3, actual: 1)
        )
        #expect(byID(try await repository.fetchShows()) == byID(seeded))
    }

    // MARK: - Helpers

    private let testBaseURL = URL(string: "https://example.supabase.co")!

    // The suite owns the container so it outlives every context it hands out.
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for:
                TeamEntity.self,
                TourEntity.self,
                ShowEntity.self,
                SyncOperationEntity.self,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true
            )
        )
    }

    private func makeTeamReconciler(
        _ repository: SwiftDataTeamRepository,
        _ context: ModelContext
    ) -> TeamReconciler {
        TeamReconciler(
            teamRepository: repository,
            syncOperationRepository: SwiftDataSyncOperationRepository(
                modelContext: context
            )
        )
    }

    private func makeTourReconciler(
        _ repository: SwiftDataTourRepository,
        _ context: ModelContext
    ) -> TourReconciler {
        TourReconciler(
            tourRepository: repository,
            syncOperationRepository: SwiftDataSyncOperationRepository(
                modelContext: context
            )
        )
    }

    private func makeShowReconciler(
        _ repository: SwiftDataShowRepository,
        _ context: ModelContext
    ) -> ShowReconciler {
        ShowReconciler(
            showRepository: repository,
            syncOperationRepository: SwiftDataSyncOperationRepository(
                modelContext: context
            )
        )
    }

    private func capturedError(
        from pull: () async throws -> Void
    ) async -> Error? {
        do {
            try await pull()
            return nil
        } catch {
            return error
        }
    }

    private func byID<Item: Identifiable>(
        _ items: [Item]
    ) -> [Item.ID: Item] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    private func makeTeams() -> [Team] {
        (1...3).map { index in
            Team(
                id: UUID(),
                name: "Team \(index)",
                genre: "Rock",
                country: "Iran",
                city: "Rasht",
                createdAt: Date(timeIntervalSince1970: 100),
                version: 1
            )
        }
    }

    private func makeTours() -> [Tour] {
        (1...3).map { index in
            Tour(
                id: UUID(),
                teamID: UUID(),
                name: "Tour \(index)",
                startDate: Date(timeIntervalSince1970: 1_000),
                endDate: Date(timeIntervalSince1970: 2_000),
                createdAt: Date(timeIntervalSince1970: 100),
                version: 1
            )
        }
    }

    private func makeShows() -> [Show] {
        (1...3).map { index in
            Show(
                id: UUID(),
                tourID: UUID(),
                name: "Show \(index)",
                venue: "Venue",
                city: "Paris",
                date: Date(timeIntervalSince1970: 1_500),
                createdAt: Date(timeIntervalSince1970: 100),
                version: 1
            )
        }
    }
}

// MARK: - Mocks

private enum PullTestError: Error, Equatable {
    case failed
}

@MainActor
private final class FailingTeamPullService: TeamPullServiceProtocol {
    func fetchTeams() async throws -> [Team] {
        throw PullTestError.failed
    }
}

@MainActor
private final class FailingTourPullService: TourPullServiceProtocol {
    func fetchTours() async throws -> [Tour] {
        throw PullTestError.failed
    }
}

@MainActor
private final class FailingShowPullService: ShowPullServiceProtocol {
    func fetchShows() async throws -> [Show] {
        throw PullTestError.failed
    }
}

private final class PullTestAuthService: SyncAuthProviding {

    func accessToken() async throws -> String {
        "test-access-token"
    }

    func userID() async throws -> UUID {
        UUID()
    }
}

/// Answers every request with the same rows and, optionally, one
/// Content-Range header.
private final class FixedResponseAPIClient: APIClientProtocol {

    private let data: Data
    private let headers: [String: String]

    init<Row: Encodable>(
        rows: [Row],
        contentRange: String?
    ) throws {
        self.data = try JSONEncoder().encode(rows)
        self.headers = contentRange.map { ["Content-Range": $0] } ?? [:]
    }

    func send<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        try await sendWithMetadata(request, responseType: responseType).body
    }

    func sendWithMetadata<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> APIClientResponse<Response> {
        let body = try JSONDecoder().decode(Response.self, from: data)

        return APIClientResponse(
            body: body,
            statusCode: 206,
            headers: headers
        )
    }
}
