//
//  SupabasePagedFetcher.swift
//  TourOps
//
//  Fetches every row in a stable order and refuses to return unverified partial data.
//

import Foundation

enum SupabasePagedFetcher {
    static let defaultPageSize = 500

    /// Fetches every row of `table` and returns them in ascending `id` order.
    ///
    /// Pages are requested with keyset pagination: every page after the first
    /// adds `id=gt.<last id of the previous page>`, so a row that existed for
    /// the whole fetch cannot be skipped by an insert or delete elsewhere in
    /// the table. The `Range` of every page is relative to that cursor
    /// (`0-(pageSize - 1)`), and `Prefer: count=exact` makes the server report
    /// in `Content-Range` how many rows remain after the cursor.
    ///
    /// The result is only returned when the whole collection has been
    /// verified: every page must carry a consistent `Content-Range`, a body
    /// that matches it, a remaining count that shrinks by exactly the rows
    /// received, and ids that strictly ascend across all pages (which also
    /// rejects duplicates). Anything else throws, so a caller can treat a
    /// returned array as complete.
    ///
    /// This is not snapshot isolation. Separate requests can still observe
    /// different database states. Rows that existed for the whole fetch are
    /// always returned; rows inserted or deleted while it runs may or may not
    /// be, and changes after the cursor are rejected as a changed total.
    static func fetchAll<Row: Decodable>(
        table: String,
        baseURL: URL,
        publishableKey: String,
        accessToken: String,
        apiClient: APIClientProtocol,
        rowType: Row.Type,
        id: KeyPath<Row, UUID>,
        pageSize: Int = defaultPageSize
    ) async throws -> [Row] {
        guard pageSize > 0 else {
            throw SupabasePaginationError.invalidPageSize
        }

        var allRows: [Row] = []
        var cursor: UUID?
        var expectedRemaining: Int?

        while true {
            let url = try pageURL(
                table: table,
                baseURL: baseURL,
                after: cursor
            )

            var request = URLRequest(url: url)
            request.httpMethod = HTTPMethod.GET.rawValue
            // A Pull must never be answered from a local URL cache.
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(publishableKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("items", forHTTPHeaderField: "Range-Unit")
            request.setValue("0-\(pageSize - 1)", forHTTPHeaderField: "Range")
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

            // After the first page the total is the number of rows left
            // after the cursor, which the previous page already told us.
            if let expectedRemaining, expectedRemaining != remoteRange.total {
                throw SupabasePaginationError.totalChanged(
                    expected: expectedRemaining,
                    actual: remoteRange.total
                )
            }

            if remoteRange.total == 0 {
                guard cursor == nil, response.body.isEmpty else {
                    throw SupabasePaginationError.invalidContentRange(contentRange)
                }
                return []
            }

            guard
                let start = remoteRange.start,
                let end = remoteRange.end,
                start == 0,
                end >= start,
                end <= pageSize - 1,
                end < remoteRange.total
            else {
                throw SupabasePaginationError.invalidContentRange(contentRange)
            }

            let pageCount = end - start + 1
            guard response.body.count == pageCount else {
                throw SupabasePaginationError.responseCountMismatch(
                    expected: pageCount,
                    actual: response.body.count
                )
            }

            var previousID = cursor
            for row in response.body {
                let rowID = row[keyPath: id]

                if let previousID, !isAscending(previousID, rowID) {
                    throw SupabasePaginationError.nonAscendingIDs
                }

                previousID = rowID
            }

            allRows.append(contentsOf: response.body)

            let remainingAfterPage = remoteRange.total - pageCount

            if remainingAfterPage == 0 {
                return allRows
            }

            cursor = previousID
            expectedRemaining = remainingAfterPage
        }
    }

    private static func pageURL(
        table: String,
        baseURL: URL,
        after cursor: UUID?
    ) throws -> URL {
        guard
            let endpoint = URL(string: "/rest/v1/\(table)", relativeTo: baseURL),
            var components = URLComponents(
                url: endpoint,
                resolvingAgainstBaseURL: true
            )
        else {
            throw SupabasePaginationError.invalidEndpoint
        }

        // UUID primary keys provide a unique, stable ordering between requests.
        var queryItems = [
            URLQueryItem(name: "order", value: "id.asc")
        ]

        if let cursor {
            queryItems.append(
                URLQueryItem(
                    name: "id",
                    value: "gt.\(cursor.uuidString.lowercased())"
                )
            )
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw SupabasePaginationError.invalidEndpoint
        }

        return url
    }

    /// PostgreSQL orders `uuid` values by comparing their bytes.
    private static func isAscending(
        _ lhs: UUID,
        _ rhs: UUID
    ) -> Bool {
        withUnsafeBytes(of: lhs.uuid) { lhsBytes in
            withUnsafeBytes(of: rhs.uuid) { rhsBytes in
                lhsBytes.lexicographicallyPrecedes(rhsBytes)
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

enum SupabasePaginationError: Error, Equatable {
    case invalidEndpoint
    case invalidPageSize
    case missingContentRange
    case invalidContentRange(String)
    case responseCountMismatch(expected: Int, actual: Int)
    case totalChanged(expected: Int, actual: Int)
    case nonAscendingIDs
}
