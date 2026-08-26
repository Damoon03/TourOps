//
//  TeamDetailView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

struct TeamDetailView: View {

    let teamID: UUID
    let viewModel: TeamListViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var showingError = false

    private var team: Team? {
        viewModel.teams.first { $0.id == teamID }
    }

    var body: some View {
        Group {
            if let team {
                List {
                    Section("Team Information") {
                        LabeledContent("Name", value: team.name)
                        LabeledContent("Genre", value: team.genre)
                        LabeledContent("Country", value: team.country)
                        LabeledContent("City", value: team.city)
                    }

                    Section("Created") {
                        Text(team.createdAt, style: .date)
                    }

                    Section {
                        Button("Delete Team", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Team Not Found",
                    systemImage: "person.3",
                    description: Text("This team is no longer available.")
                )
            }
        }
        .navigationTitle(team?.name ?? "Team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEdit = true
                }
                .disabled(team == nil)
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let team {
                NavigationStack {
                    EditTeamView(
                        team: team,
                        viewModel: viewModel
                    )
                }
            }
        }
        .confirmationDialog(
            "Delete Team?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let team else { return }

                Task {
                    let success = await viewModel.deleteTeam(team)

                    if success {
                        dismiss()
                    } else {
                        showingError = true
                    }
                }
            }

            Button("Cancel", role: .cancel) {
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert(
            "Error",
            isPresented: $showingError
        ) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
    }
}

#Preview {
    Text("Team Detail Preview")
}
