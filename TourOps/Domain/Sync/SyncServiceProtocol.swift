//
//  SyncServiceProtocol.swift
//  TourOps
//
//  Created by Damoon saber on 9/8/1405 AP.
//

import Foundation

protocol SyncServiceProtocol {
    func execute(_ operation: SyncOperation) async throws
}
