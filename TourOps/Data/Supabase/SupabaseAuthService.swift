//
//  SupabaseAuthService.swift
//  TourOps
//
//  Created by Damoon saber on 11/6/1405 AP.
//

import Foundation
import Supabase

final class SupabaseAuthService {

    private let client: SupabaseClient

    init(
        client: SupabaseClient = TourOpsSupabaseClient.shared.client
    ) {
        self.client = client
    }

    func signIn(
        email: String,
        password: String
    ) async throws {
        try await client.auth.signIn(
            email: email,
            password: password
        )
    }

    func accessToken() async throws -> String {
        let session = try await client.auth.session

        return session.accessToken
    }

    func userID() async throws -> UUID {
        let session = try await client.auth.session

        return session.user.id
    }
}
