//
//  LoginView.swift
//  TourOps
//
//  Created by Damoon saber on 7/5/1405 AP.
//

import SwiftUI

struct LoginView: View {

    private let authService: SupabaseAuthService

    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    init(
        authService: SupabaseAuthService = SupabaseAuthService()
    ) {
        self.authService = authService
    }

    var body: some View {

        VStack(spacing: 20) {

            Text("TourOps")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Sign in to continue")
                .foregroundStyle(.secondary)

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                signIn()
            } label: {
                if isSigningIn {
                    ProgressView()
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                email.isEmpty ||
                password.isEmpty ||
                isSigningIn
            )
        }
        .padding()
    }
}

private extension LoginView {

    func signIn() {

        errorMessage = nil
        isSigningIn = true

        Task {

            do {

                try await authService.signIn(
                    email: email,
                    password: password
                )

            } catch {

                errorMessage = error.localizedDescription
                isSigningIn = false
            }
        }
    }
}

#Preview {
    LoginView()
}
