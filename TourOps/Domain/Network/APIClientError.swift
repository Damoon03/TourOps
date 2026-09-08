//
//  APIClientError.swift
//  TourOps
//
//  Created by Damoon saber on 9/9/1405 AP.
//

import Foundation

enum APIClientError: Error {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)

    var isRetryable: Bool {
        switch self {
        case .invalidResponse:
            return true

        case .httpError(let statusCode):
            return statusCode >= 500

        case .decodingError:
            return false
        }
    }
}
