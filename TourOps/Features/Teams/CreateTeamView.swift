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
                        Task {
                            await viewModel.createTeam(
                                name: name,
                                genre: genre,
                                country: country,
                                city: city
                            )

                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}
