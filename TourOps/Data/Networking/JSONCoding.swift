//
//  JSONCoding.swift
//  TourOps
//
//  Created by Damoon saber on 1/7/1405 AP.
//

import Foundation

enum JSONCoding {

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            let withFractionalSeconds = ISO8601DateFormatter()
            withFractionalSeconds.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]

            if let date = withFractionalSeconds.date(from: dateString) {
                return date
            }

            let withoutFractionalSeconds = ISO8601DateFormatter()
            withoutFractionalSeconds.formatOptions = [
                .withInternetDateTime
            ]

            if let date = withoutFractionalSeconds.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO 8601 date: \(dateString)"
            )
        }
        return decoder
    }()
}
