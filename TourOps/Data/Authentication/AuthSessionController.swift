//
//  AuthSessionController.swift
//  TourOps
//
//  Created by Damoon saber on 7/4/1405 AP.
//

import Foundation
import Supabase

@MainActor
@Observable
final class AuthSessionController {

    private let client: SupabaseClient

    private(set) var state: AuthState = .loading

    init(
        client: SupabaseClient = TourOpsSupabaseClient.shared.client
    ) {
        self.client = client
    }

    func start() async {

        for await event in client.auth.authStateChanges {

            switch event.event {

            case .initialSession:
                updateState(for: event.session)

            case .signedIn,
                 .tokenRefreshed,
                 .userUpdated:
                state = .signedIn

            case .signedOut:
                state = .signedOut

            default:
                break
            }
        }
    }
}

private extension AuthSessionController {

    func updateState(
        for session: Session?
    ) {

        guard let session else {
            state = .signedOut
            return
        }

        state = session.isExpired
            ? .signedOut
            : .signedIn
    }
}
