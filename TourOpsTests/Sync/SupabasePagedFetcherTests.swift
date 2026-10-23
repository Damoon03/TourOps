import Foundation
import Testing
@testable import TourOps

struct SupabasePagedFetcherTests {
    @Test
    func fetchAllCombinesEveryPage() async throws {
        let client = MockPagedAPIClient(responses: [
            MockAPIResponse(
                body: [TestRow(id: 1), TestRow(id: 2)],
                headers: ["Content-Range": "0-1/3"]
            ),
            MockAPIResponse(
                body: [TestRow(id: 3)],
                headers: ["Content-Range": "2-2/3"]
            )
        ])

        let rows: [TestRow] = try await SupabasePagedFetcher.fetchAll(
            table: "teams",
            baseURL: URL(string: "https://example.supabase.co")!,
            publishableKey: "test-key",
            accessToken: "test-token",
            apiClient: client,
            rowType: TestRow.self,
            pageSize: 2
        )

        #expect(rows == [TestRow(id: 1), TestRow(id: 2), TestRow(id: 3)])
        #expect(client.requests.count == 2)
        #expect(client.requests[0].value(forHTTPHeaderField: "Range") == "0-1")
        #expect(client.requests[1].value(forHTTPHeaderField: "Range") == "2-3")
        #expect(client.requests[0].value(forHTTPHeaderField: "Prefer") == "count=exact")
        #expect(client.requests[0].value(forHTTPHeaderField: "Range-Unit") == "items")
    }

    @Test
    func fetchAllContinuesWhenServerReturnsShortPage() async throws {
        let client = MockPagedAPIClient(responses: [
            MockAPIResponse(
                body: [TestRow(id: 1)],
                headers: ["Content-Range": "0-0/3"]
            ),
            MockAPIResponse(
                body: [TestRow(id: 2)],
                headers: ["Content-Range": "1-1/3"]
            ),
            MockAPIResponse(
                body: [TestRow(id: 3)],
                headers: ["Content-Range": "2-2/3"]
            )
        ])

        let rows: [TestRow] = try await SupabasePagedFetcher.fetchAll(
            table: "teams",
            baseURL: URL(string: "https://example.supabase.co")!,
            publishableKey: "test-key",
            accessToken: "test-token",
            apiClient: client,
            rowType: TestRow.self,
            pageSize: 2
        )

        #expect(rows == [TestRow(id: 1), TestRow(id: 2), TestRow(id: 3)])
        #expect(client.requests.count == 3)
    }

    @Test
    func fetchAllAcceptsConfirmedEmptyCollection() async throws {
        let client = MockPagedAPIClient(responses: [
            MockAPIResponse(
                body: [TestRow](),
                headers: ["Content-Range": "*/0"]
            )
        ])

        let rows: [TestRow] = try await SupabasePagedFetcher.fetchAll(
            table: "teams",
            baseURL: URL(string: "https://example.supabase.co")!,
            publishableKey: "test-key",
            accessToken: "test-token",
            apiClient: client,
            rowType: TestRow.self,
            pageSize: 2
        )

        #expect(rows.isEmpty)
    }

    @Test
    func missingContentRangeFailsClosed() async {
        let client = MockPagedAPIClient(responses: [
            MockAPIResponse(body: [TestRow(id: 1)], headers: [:])
        ])

        do {
            let _: [TestRow] = try await SupabasePagedFetcher.fetchAll(
                table: "teams",
                baseURL: URL(string: "https://example.supabase.co")!,
                publishableKey: "test-key",
                accessToken: "test-token",
                apiClient: client,
                rowType: TestRow.self,
                pageSize: 2
            )
            Issue.record("Expected missing pagination metadata")
        } catch SupabasePaginationError.missingContentRange {
            // Unverified data must not reach the reconciler.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func truncatedBodyFailsClosed() async {
        let client = MockPagedAPIClient(responses: [
            MockAPIResponse(
                body: [TestRow(id: 1)],
                headers: ["Content-Range": "0-1/3"]
            )
        ])

        do {
            let _: [TestRow] = try await SupabasePagedFetcher.fetchAll(
                table: "teams",
                baseURL: URL(string: "https://example.supabase.co")!,
                publishableKey: "test-key",
                accessToken: "test-token",
                apiClient: client,
                rowType: TestRow.self,
                pageSize: 2
            )
            Issue.record("Expected body/range mismatch to abort the pull")
        } catch SupabasePaginationError.responseCountMismatch {
            // Expected.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func changingTotalFailsClosed() async {
        let client = MockPagedAPIClient(responses: [
            MockAPIResponse(
                body: [TestRow(id: 1), TestRow(id: 2)],
                headers: ["Content-Range": "0-1/3"]
            ),
            MockAPIResponse(
                body: [TestRow(id: 3)],
                headers: ["Content-Range": "2-2/4"]
            )
        ])

        do {
            let _: [TestRow] = try await SupabasePagedFetcher.fetchAll(
                table: "teams",
                baseURL: URL(string: "https://example.supabase.co")!,
                publishableKey: "test-key",
                accessToken: "test-token",
                apiClient: client,
                rowType: TestRow.self,
                pageSize: 2
            )
            Issue.record("Expected total change to abort the pull")
        } catch SupabasePaginationError.totalChanged {
            // Do not reconcile a changing collection.
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func invalidPageSizeFailsClosed() async {
        let client = MockPagedAPIClient(responses: [])

        do {
            let _: [TestRow] = try await SupabasePagedFetcher.fetchAll(
                table: "teams",
                baseURL: URL(string: "https://example.supabase.co")!,
                publishableKey: "test-key",
                accessToken: "test-token",
                apiClient: client,
                rowType: TestRow.self,
                pageSize: 0
            )
            Issue.record("Expected invalid page size")
        } catch SupabasePaginationError.invalidPageSize {
            #expect(client.requests.isEmpty)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private struct TestRow: Decodable, Equatable {
    let id: Int
}

private struct MockAPIResponse {
    let body: Any
    let headers: [String: String]
}

private final class MockPagedAPIClient: APIClientProtocol {
    private let responses: [MockAPIResponse]
    private var responseIndex = 0
    private(set) var requests: [URLRequest] = []

    init(responses: [MockAPIResponse]) {
        self.responses = responses
    }

    func send<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response {
        try await sendWithMetadata(
            request,
            responseType: responseType
        ).body
    }

    func sendWithMetadata<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> APIClientResponse<Response> {
        guard responseIndex < responses.count else {
            throw SupabasePaginationError.emptyPage
        }

        let response = responses[responseIndex]
        responseIndex += 1
        requests.append(request)

        return APIClientResponse(
            body: response.body as! Response,
            statusCode: 206,
            headers: response.headers
        )
    }
}
