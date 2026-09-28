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
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
