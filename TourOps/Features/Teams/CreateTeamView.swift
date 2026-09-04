//
//  CreateTeamView.swift
//  TourOps
//
//  Created by Damoon saber on 6/3/1405 AP.
//

import SwiftUI

struct CreateTeamView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: TeamListViewModel

    @State private var name = ""
    @State private var genre = ""
    @State private var country = ""
    @State private var city = ""
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Team Information") {
                    TextField("Name", text: $name)
                    TextField("Genre", text: $genre)
                    TextField("Country", text: $country)
                    TextField("City", text: $city)
                }
            }
            .navigationTitle("New Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let team = Team(
                            id: UUID(),
                            name: name,
                            genre: genre,
                            country: country,
                            city: city,
                            createdAt: Date(),
                            version: 1
                        )

                        Task {
                            let success = await viewModel.createTeam(team)

                            if success {
                                dismiss()
                            } else {
                                showingError = true
                            }
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .alert(
            "Error",
            isPresented: $showingError
        ) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(
                viewModel.errorMessage
                ?? "Something went wrong."
            )
        }
    }
}

#Preview {
    Text("Create Team Preview")
}
