//
//  TeamListView.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import SwiftUI

struct TeamListView: View {

    let repository: TeamRepositoryProtocol
    let tourRepository: TourRepositoryProtocol

    @State private var viewModel: TeamListViewModel
    @State private var showingCreateTeam = false

    init(
        repository: TeamRepositoryProtocol,
        tourRepository: TourRepositoryProtocol
    ) {
        self.repository = repository
        self.tourRepository = tourRepository

        _viewModel = State(
            initialValue: TeamListViewModel(
                repository: repository
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Unable to Load Teams",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.teams.isEmpty {
                    ContentUnavailableView(
                        "No Teams",
                        systemImage: "person.3",
                        description: Text(
                            "Create your first team to get started."
                        )
                    )
                } else {
                    List(viewModel.teams) { team in
                        NavigationLink {
                            TeamDetailView(
                                teamID: team.id,
                                viewModel: viewModel,
                                tourRepository: tourRepository
                            )
                        } label: {
                            VStack(alignment: .leading) {
                                Text(team.name)
                                    .font(.headline)

                                Text("\(team.genre) • \(team.city)")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Teams")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateTeam = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateTeam) {
                CreateTeamView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadTeams()
            }
        }
    }
}
