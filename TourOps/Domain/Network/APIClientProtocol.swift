//
//  APIClientProtocol.swift
//  TourOps
//
//  Created by Damoon saber on 9/9/1405 AP.
//

import Foundation

protocol APIClientProtocol {
    func send<Response: Decodable>(
        _ request: URLRequest,
        responseType: Response.Type
    ) async throws -> Response
}
