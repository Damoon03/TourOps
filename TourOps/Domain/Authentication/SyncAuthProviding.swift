//
//  SyncAuthProviding.swift
//  TourOps
//
//  Created by Damoon saber on 7/6/1405 AP.
//

import Foundation

protocol SyncAuthProviding {

    func accessToken() async throws -> String

    func userID() async throws -> UUID
}
