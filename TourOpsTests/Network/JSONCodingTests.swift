//
//  JSONCodingTests.swift
//  TourOpsTests
//

import Foundation
import Testing
@testable import TourOps

struct JSONCodingTests {

    @Test
    func decoderAcceptsISO8601TimestampsWithoutFractionalSeconds() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Northbound",
            "genre": "Rock",
            "country": "Iran",
            "city": "Rasht",
            "created_at": "2026-01-01T00:00:00Z",
            "version": 1
        }
        """

        let dto = try JSONCoding.decoder.decode(
            TeamDTO.self,
            from: Data(json.utf8)
        )

        #expect(dto.createdAt == dateFromISO8601("2026-01-01T00:00:00Z"))
    }

    @Test
    func decoderAcceptsISO8601TimestampsWithFractionalSeconds() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Northbound",
            "genre": "Rock",
            "country": "Iran",
            "city": "Rasht",
            "created_at": "2026-01-01T00:00:00.123456Z",
            "version": 1
        }
        """

        let dto = try JSONCoding.decoder.decode(
            TeamDTO.self,
            from: Data(json.utf8)
        )

        let expected = dateFromISO8601(
            "2026-01-01T00:00:00.123456Z",
            includingFractionalSeconds: true
        )

        #expect(dto.createdAt == expected)
    }

    @Test
    func decoderAcceptsISO8601TimestampsWithNumericOffset() throws {
        let json = """
        {
            "id": "00000000-0000-0000-0000-000000000001",
            "name": "Northbound",
            "genre": "Rock",
            "country": "Iran",
            "city": "Rasht",
            "created_at": "2026-01-01T00:00:00.123456+00:00",
            "version": 1
        }
        """

        let dto = try JSONCoding.decoder.decode(
            TeamDTO.self,
            from: Data(json.utf8)
        )

        let expected = dateFromISO8601(
            "2026-01-01T00:00:00.123456+00:00",
            includingFractionalSeconds: true
        )

        #expect(dto.createdAt == expected)
    }
}

private func dateFromISO8601(
    _ string: String,
    includingFractionalSeconds: Bool = false
) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = includingFractionalSeconds
        ? [.withInternetDateTime, .withFractionalSeconds]
        : [.withInternetDateTime]

    return formatter.date(from: string)!
}
