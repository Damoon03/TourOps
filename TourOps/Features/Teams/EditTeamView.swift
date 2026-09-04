//
//  EditTeamView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

struct EditTeamView: View {
    let team: Team
    let viewModel: TeamListViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var genre: String
    @State private var country: String
    @State private var city: String
    @State private var showingError = false

    init(
        team: Team,
        viewModel: TeamListViewModel
    ) {
        self.team = team
        self.viewModel = viewModel

        _name = State(initialValue: team.name)
        _genre = State(initialValue: team.genre)
        _country = State(initialValue: team.country)
        _city = State(initialValue: team.city)
    }

    var body: some View {
        Form {
            Section("Team Information") {
                TextField("Name", text: $name)
                TextField("Genre", text: $genre)
                TextField("Country", text: $country)
                TextField("City", text: $city)
            }
        }
        .navigationTitle("Edit Team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let updatedTeam = Team(
                        id: team.id,
                        name: name,
                        genre: genre,
                        country: country,
                        city: city,
                        createdAt: team.createdAt,
                        version: team.version
                    )

                    Task {
                        let success = await viewModel.updateTeam(
                            updatedTeam
                        )

                        if success {
                            dismiss()
                        } else {
                            showingError = true
                        }
                    }
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
    Text("Edit Team Preview")
}
