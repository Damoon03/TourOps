import Foundation
import Testing
@testable import TourOps

struct SupabasePagedFetcherTests {
    @Test
    func fetchAllCombinesEveryPageUsingAnIDCursor() async throws {
        let client = MockPagedAPIClient(steps: [
            .page(MockPage(rows(1...2), contentRange: "0-1/3")),
            .page(MockPage(rows(3...3), contentRange: "0-0/1", statusCode: 200))
        ])

        let result = try await fetchRows(using: client)

        #expect(result == rows(1...3))
        #expect(client.requests.count == 2)

        let base = "https://example.supabase.co/rest/v1/teams?order=id.asc"
        #expect(client.requests[0].url?.absoluteString == base)
        #expect(
            client.requests[1].url?.absoluteString
            == base + "&id=gt." + row(2).id.uuidString.lowercased()
        )

        for request in client.requests {
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Range") == "0-1")
            #expect(request.value(forHTTPHeaderField: "Range-Unit") == "items")
            #expect(request.value(forHTTPHeaderField: "Prefer") == "count=exact")
            #expect(request.value(forHTTPHeaderField: "apikey") == "test-key")
            #expect(
                request.value(forHTTPHeaderField: "Authorization")
                == "Bearer test-token"
            )
        }
    }

    @Test
    func fetchAllContinuesWhenServerReturnsShortPages() async throws {
        let client = MockPagedAPIClient(steps: [
            .page(MockPage(rows(1...1), contentRange: "0-0/3")),
            .page(MockPage(rows(2...2), contentRange: "0-0/2")),
            .page(MockPage(rows(3...3), contentRange: "0-0/1", statusCode: 200))
        ])

        let result = try await fetchRows(using: client)

        #expect(result == rows(1...3))
        #expect(client.requests.count == 3)
    }

    @Test
    func fetchAllAcceptsConfirmedEmptyCollection() async throws {
        let client = MockPagedAPIClient(steps: [
            .page(MockPage([], contentRange: "*/0", statusCode: 200))
        ])

        let result = try await fetchRows(using: client)

        #expect(result.isEmpty)
        #expect(client.requests.count == 1)
    }

    @Test
    func missingContentRangeFailsClosed() async {
        let client = MockPagedAPIClient(steps: [
            .page(MockPage(rows(1...1), contentRange: nil, statusCode: 200))
        ])

        await expectFailure(.missingContentRange, using: client)
    }

    @Test
    func truncatedBodyFailsClosed() async {
        let client = MockPagedAPIClient(steps: [
            .page(MockPage(rows(1...1), contentRange: "0-1/3"))
        ])

        await expectFailure(
            .responseCountMismatch(expected: 2, actual: 1),
            using: client
        )
    }

    @Test
    func changingRemainingTotalFailsClosed() async {
        // After the first page two rows are expected to remain after the
        // cursor, so a later page that reports three means rows changed.
        let client = MockPagedAPIClient(steps: [
            .page(MockPage(rows(1...2), contentRange: "0-1/4")),
            .page(MockPage(rows(3...4), contentRange: "0-1/3"))
        ])

        await expectFailure(
            .totalChanged(expected: 2, actual: 3),
            using: client
        )
    }

    @Test
    func repeatedIDAcrossPagesFailsClosed() async {
        let client = MockPagedAPIClient(steps: [
            .page(MockPage(rows(1...2), contentRange: "0-1/4")),
            .page(MockPage([row(2), row(3)], contentRange: "0-1/2", statusCode: 200))
        ])

        await expectFailure(.nonAscendingIDs, using: client)
    }

    @Test
    func repeatedIDWithinAPageFailsClosed() async {
        let client = MockPagedAPIClient(steps: [
            .page(MockPage([row(1), row(1)], contentRange: "0-1/2", statusCode: 200))
        ])

        await expectFailure(.nonAscendingIDs, using: client)
    }

    @Test
    func pageRequestsIgnoreTheLocalURLCache() async throws {
        let client = MockPagedAPIClient(steps: [
            .page(MockPage(rows(1...2), contentRange: "0-1/3")),
            .page(MockPage(rows(3...3), contentRange: "0-0/1", statusCode: 200))
        ])

        _ = try await fetchRows(using: client)

        #expect(client.requests.count == 2)

        for request in client.requests {
            #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        }
    }

    @Test
    func invalidPageSizeFailsClosed() async {
        let client = MockPagedAPIClient(steps: [])

        await expectFailure(.invalidPageSize, using: client, pageSize: 0)

        #expect(client.requests.isEmpty)
    }
}

// MARK: - Helpers

private func fetchRows(
    using client: APIClientProtocol,
    pageSize: Int = 2
) async throws -> [TestRow] {
    try await SupabasePagedFetcher.fetchAll(
        table: "teams",
        baseURL: URL(string: "https://example.supabase.co")!,
        publishableKey: "test-key",
        accessToken: "test-token",
        apiClient: client,
        rowType: TestRow.self,
        id: \.id,
        pageSize: pageSize
    )
}

private func expectFailure(
    _ expected: SupabasePaginationError,
    using client: APIClientProtocol,
    pageSize: Int = 2
) async {
    do {
        _ = try await fetchRows(using: client, pageSize: pageSize)
        Issue.record("Expected \(expected) but the fetch succeeded")
    } catch let error as SupabasePaginationError {
        #expect(error == expected)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

/// A row whose id sorts by `number`, like PostgreSQL orders uuid values.
private func row(_ number: Int) -> TestRow {
    TestRow(
        id: UUID(
            uuidString: String(
                format: "00000000-0000-0000-0000-%012lx",
                number
            )
        )!
    )
}

private func rows(_ numbers: ClosedRange<Int>) -> [TestRow] {
    numbers.map(row)
}

// MARK: - Mock

private struct TestRow: Codable, Equatable {
    let id: UUID
}

private struct MockPage {
    let rows: [TestRow]
    let headers: [String: String]
    let statusCode: Int

    /// A real server answers 206 when more rows remain and 200 when the
    /// response holds everything that matched.
    init(
        _ rows: [TestRow],
        contentRange: String?,
        statusCode: Int = 206,
        headerName: String = "Content-Range"
    ) {
        self.rows = rows
        self.headers = contentRange.map { [headerName: $0] } ?? [:]
        self.statusCode = statusCode
    }
}

private enum MockStep {
    case page(MockPage)
    case failure(Error)
}

private enum MockPagedAPIClientError: Error {
    case noResponseConfigured
}

private final class MockPagedAPIClient: APIClientProtocol {
    private var steps: [MockStep]
    private(set) var requests: [URLRequest] = []

    init(steps: [MockStep]) {
        self.steps = steps
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
        requests.append(request)

        guard !steps.isEmpty else {
            throw MockPagedAPIClientError.noResponseConfigured
        }

        switch steps.removeFirst() {
        case .failure(let error):
            throw error

        case .page(let page):
            // Decode the encoded rows so the mock needs no force cast and
            // exercises the same Decodable path as a real response.
            let data = try JSONEncoder().encode(page.rows)
            let body = try JSONDecoder().decode(Response.self, from: data)

            return APIClientResponse(
                body: body,
                statusCode: page.statusCode,
                headers: page.headers
            )
        }
    }
}
