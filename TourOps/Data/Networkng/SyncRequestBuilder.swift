//
//  SyncRequestBuilder.swift
//  TourOps
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation

final class SyncRequestBuilder: SyncRequestBuilderProtocol {

    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }


    func build(
        from operation: SyncOperation
    ) throws -> URLRequest {

        let endpoint = makeEndpoint(
            from: operation
        )

        guard let url = URL(
            string: endpoint.path,
            relativeTo: baseURL
        ) else {
            throw APIClientError.invalidResponse
            
        }

        var request = URLRequest(url: url)

        request.httpMethod = endpoint.method.rawValue

        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )

        if let payload = operation.payload {
            request.httpBody = payload.data(
                using: .utf8
            )
        }

        return request
    }


    private func makeEndpoint(
        from operation: SyncOperation
    ) -> SyncEndpoint {

        switch operation.entityType {

        case .team:
            return .team(
                id: operation.entityID,
                operation: operation.operationType
            )

        case .tour:
            return .tour(
                id: operation.entityID,
                operation: operation.operationType
            )

        case .show:
            return .show(
                id: operation.entityID,
                operation: operation.operationType
            )
        }
    }
}
