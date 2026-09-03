//
//  SyncRequestBuilderProtocol.swift
//  TourOps
//

import Foundation

protocol SyncRequestBuilderProtocol {

    func build(
        from operation: SyncOperation
    ) throws -> URLRequest
}
