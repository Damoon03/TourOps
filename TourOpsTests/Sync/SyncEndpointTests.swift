//
//  SyncEndpointTests.swift
//  TourOps
//
//  Created by Damoon saber on 10/6/1405 AP.
//

import Foundation
import Testing
@testable import TourOps

struct SyncEndpointTests {

    @Test
    func teamUpdateIncludesVersionFilter() {
        let id = UUID()

        let endpoint = SyncEndpoint.team(
            id: id,
            operation: .update,
            version: 2
        )

        #expect(
            endpoint.path ==
            "/rest/v1/teams?id=eq.\(id.uuidString)&version=eq.2"
        )

        #expect(endpoint.method == .PATCH)
    }

    @Test
    func tourUpdateIncludesVersionFilter() {
        let id = UUID()

        let endpoint = SyncEndpoint.tour(
            id: id,
            operation: .update,
            version: 5
        )

        #expect(
            endpoint.path ==
            "/rest/v1/tours?id=eq.\(id.uuidString)&version=eq.5"
        )

        #expect(endpoint.method == .PATCH)
    }

    @Test
    func showUpdateIncludesVersionFilter() {
        let id = UUID()

        let endpoint = SyncEndpoint.show(
            id: id,
            operation: .update,
            version: 3
        )

        #expect(
            endpoint.path ==
            "/rest/v1/shows?id=eq.\(id.uuidString)&version=eq.3"
        )

        #expect(endpoint.method == .PATCH)
    }

    @Test
    func createDoesNotIncludeVersionFilter() {
        let id = UUID()

        let endpoint = SyncEndpoint.team(
            id: id,
            operation: .create,
            version: 99
        )

        #expect(
            endpoint.path ==
            "/rest/v1/teams"
        )

        #expect(endpoint.method == .POST)
    }

    @Test
    func deleteIncludesVersionFilter() {
        let id = UUID()

        let endpoint = SyncEndpoint.team(
            id: id,
            operation: .delete,
            version: 99
        )

        #expect(
            endpoint.path ==
            "/rest/v1/teams?id=eq.\(id.uuidString)&version=eq.99"
        )

        #expect(endpoint.method == .DELETE)
    }
}
