//
//  SupabasePagedFetcher.swift
//  TourOps
//
//  Fetches every row in a stable order and refuses to return unverified partial data.
//

import Foundation

enum SupabasePagedFetcher {
    static let defaultPageSize = 500

    static func fetchAll<Row: Decodable>(
        table: String,
        baseURL: URL,
        publishableKey: String,
        accessToken: String,
        apiClient: APIClientProtocol,
        rowType: Row.Type,
        pageSize: Int = defaultPageSize
    ) async throws -> [Row] {
        guard pageSize > 0 else {
            throw SupabasePaginationError.invalidPageSize
        }

        guard
            let endpoint = URL(string: "/rest/v1/\(table)", relativeTo: baseURL),
            var components = URLComponents(
                url: endpoint,
                resolvingAgainstBaseURL: true
            )
        else {
            throw SupabasePaginationError.invalidEndpoint
        }

        // UUID primary keys provide a unique, stable ordering between range requests.
        components.queryItems = [
            URLQueryItem(name: "order", value: "id.asc")
        ]

        guard let url = components.url else {
            throw SupabasePaginationError.invalidEndpoint
        }

        var allRows: [Row] = []
        var offset = 0
        var expectedTotal: Int?

        while true {
            let requestedEnd = offset + pageSize - 1
            var request = URLRequest(url: url)
            request.httpMethod = HTTPMethod.GET.rawValue
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("items", forHTTPHeaderField: "Range-Unit")
            request.setValue("\(offset)-\(requestedEnd)", forHTTPHeaderField: "Range")
            request.setValue("count=exact", forHTTPHeaderField: "Prefer")

            let response: APIClientResponse<[Row]> = try await apiClient.sendWithMetadata(
                request,
                responseType: [Row].self
            )

            guard let contentRange = response.value(
                forHTTPHeaderField: "Content-Range"
            ) else {
                throw SupabasePaginationError.missingContentRange
            }

            let remoteRange = try parseContentRange(contentRange)

            if remoteRange.total == 0 {
                guard offset == 0, response.body.isEmpty else {
                    throw SupabasePaginationError.invalidContentRange(contentRange)
                }
                return []
            }

            guard
                let start = remoteRange.start,
                let end = remoteRange.end,
                start == offset,
                end >= start,
                end <= requestedEnd,
                end < remoteRange.total
            else {
                throw SupabasePaginationError.invalidContentRange(contentRange)
            }

            let expectedPageCount = end - start + 1
            guard response.body.count == expectedPageCount else {
                throw SupabasePaginationError.responseCountMismatch(
                    expected: expectedPageCount,
                    actual: response.body.count
                )
            }

            if let expectedTotal, expectedTotal != remoteRange.total {
                throw SupabasePaginationError.totalChanged(
                    expected: expectedTotal,
                    actual: remoteRange.total
                )
            }
            expectedTotal = remoteRange.total

            guard !response.body.isEmpty else {
                throw SupabasePaginationError.emptyPage
            }

            allRows.append(contentsOf: response.body)
            offset = end + 1

            if offset == remoteRange.total {
                return allRows
            }
        }
    }

    private static func parseContentRange(
        _ value: String
    ) throws -> ParsedContentRange {
        let parts = value.split(
            separator: "/",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )

        guard
            parts.count == 2,
            let total = Int(parts[1].trimmingCharacters(in: .whitespaces)),
            total >= 0
        else {
            throw SupabasePaginationError.invalidContentRange(value)
        }

        let boundsValue = parts[0].trimmingCharacters(in: .whitespaces)
        if boundsValue == "*", total == 0 {
            return ParsedContentRange(start: nil, end: nil, total: 0)
        }

        let bounds = boundsValue.split(
            separator: "-",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )

        guard
            bounds.count == 2,
            let start = Int(bounds[0]),
            let end = Int(bounds[1]),
            start >= 0,
            end >= start,
            total > 0
        else {
            throw SupabasePaginationError.invalidContentRange(value)
        }

        return ParsedContentRange(start: start, end: end, total: total)
    }
}

private struct ParsedContentRange {
    let start: Int?
    let end: Int?
    let total: Int
}

enum SupabasePaginationError: Error {
    case invalidEndpoint
    case invalidPageSize
    case missingContentRange
    case invalidContentRange(String)
    case responseCountMismatch(expected: Int, actual: Int)
    case totalChanged(expected: Int, actual: Int)
    case emptyPage
}
