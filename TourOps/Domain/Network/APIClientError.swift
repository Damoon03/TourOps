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
}
