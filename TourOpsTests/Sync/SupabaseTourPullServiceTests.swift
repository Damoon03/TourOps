import Foundation
import Testing
@testable import TourOps

struct SupabaseTourPullServiceTests {

    @Test
    func fetchToursReturnsMappedTours() async throws {
        let tourID = UUID()
        let teamID = UUID()
        let startDate = Date(timeIntervalSince1970: 1_000)
        let endDate = Date(timeIntervalSince1970: 2_000)
        let createdAt = Date(timeIntervalSince1970: 100)

        let apiClient = TourMockAPIClient(
            response: [
                TourDTO(
                    id: tourID,
                    teamID: teamID,
                    name: "Summer Tour",
                    startDate: startDate,
                    endDate: endDate,
                    createdAt: createdAt,
                    version: 3
                )
            ]
        )

        let authService = TourMockAuthService()

        let service = SupabaseTourPullService(
            apiClient: apiClient,
            authService: authService,
            baseURL: URL(string: "https://example.supabase.co")!
        )

        let tours = try await service.fetchTours()

        #expect(
            tours == [
                Tour(
                    id: tourID,
                    teamID: teamID,
                    name: "Summer Tour",
                    startDate: startDate,
                    endDate: endDate,
                    createdAt: createdAt,
                    version: 3
                )
            ]
        )

        #expect(apiClient.sendCallCount == 1)
        #expect(authService.accessTokenCallCount == 1)
    }

    @Test
    func fetchToursReturnsEmptyListForConfirmedEmptyCollection() async throws {
        let service = SupabaseTourPullService(
            apiClient: TourMockAPIClient(response: []),
            authService: TourMockAuthService(),
            baseURL: URL(string: "https://example.supabase.co")!
        )

        let tours = try await service.fetchTours()

        #expect(tours.isEmpty)
    }

    @Test
    func fetchToursBuildsAuthenticatedPagedGETRequest() async throws {
        let apiClient = TourMockAPIClient(response: [])

        let service = SupabaseTourPullService(
            apiClient: apiClient,
            authService: TourMockAuthService(),
            baseURL: URL(string: "https://example.supabase.co")!
        )

        _ = try await service.fetchTours()

        let request = apiClient.lastRequest

        #expect(request?.httpMethod == "GET")
        #expect(
            request?.url?.absoluteString
            == "https://example.supabase.co/rest/v1/tours?order=id.asc"
        )
        #expect(
            request?.value(forHTTPHeaderField: "Authorization")
            == "Bearer test-access-token"
        )
        #expect(request?.value(forHTTPHeaderField: "Range-Unit") == "items")
        #expect(request?.value(forHTTPHeaderField: "Prefer") == "count=exact")
        #expect(request?.cachePolicy == .reloadIgnoringLocalCacheData)
    }

    @Test
    func fetchToursFailsWhenResponseCarriesNoPaginationMetadata() async {
        // Even an empty list must not be trusted without a Content-Range,
        // because the reconciler would treat it as "nothing exists remotely".
        let service = SupabaseTourPullService(
            apiClient: SendOnlyAPIClient(responseData: Data("[]".utf8)),
            authService: TourMockAuthService(),
            baseURL: URL(string: "https://example.supabase.co")!
        )

        do {
            _ = try await service.fetchTours()
            Issue.record("Expected the pull to fail without pagination metadata")
        } catch SupabasePaginationError.missingContentRange {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func fetchToursPropagatesAuthenticationFailure() async {
        let service = SupabaseTourPullService(
            apiClient: TourMockAPIClient(response: []),
            authService: TourMockAuthService(failure: TourTestError.authentication),
            baseURL: URL(string: "https://example.supabase.co")!
        )

        do {
            _ = try await service.fetchTours()
            Issue.record("Expected the authentication error to propagate")
        } catch TourTestError.authentication {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private enum TourTestError: Error {
    case authentication
}

private final class TourMockAPIClient: APIClientProtocol {

    private let response: [TourDTO]

    private(set) var sendCallCount = 0
    private(set) var lastRequest: URLRequest?

    init(response: [TourDTO]) {
        self.response = response
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
        sendCallCount += 1
        lastRequest = request

        let data = try JSONEncoder().encode(response)
        let body = try JSONDecoder().decode(Response.self, from: data)

        let contentRange = response.isEmpty
            ? "*/0"
            : "0-\(response.count - 1)/\(response.count)"

        return APIClientResponse(
            body: body,
            statusCode: 200,
            headers: ["Content-Range": contentRange]
        )
    }
}

private final class TourMockAuthService: SyncAuthProviding {

    private let failure: Error?

    private(set) var accessTokenCallCount = 0

    init(failure: Error? = nil) {
        self.failure = failure
    }

    func accessToken() async throws -> String {
        accessTokenCallCount += 1

        if let failure {
            throw failure
        }

        return "test-access-token"
    }

    func userID() async throws -> UUID {
        UUID()
    }
}
