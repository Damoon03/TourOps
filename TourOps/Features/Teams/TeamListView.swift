//
//  TeamListView.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import SwiftUI

struct TeamListView: View {
    @State private var viewModel: TeamListViewModel

    init(repository: TeamRepositoryProtocol) {
        _viewModel = State(
            initialValue: TeamListViewModel(repository: repository)
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let errorMessage = viewModel.errorMessage {
                    ContentUnavailableView(
                        "Something went wrong",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.teams.isEmpty {
                    ContentUnavailableView(
                        "No Teams",
                        systemImage: "person.3",
                        description: Text("Your teams will appear here.")
                    )
                } else {
                    List(viewModel.teams) { team in
                        VStack(alignment: .leading) {
                            Text(team.name)
                                .font(.headline)

                            Text("\(team.city), \(team.country)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Teams")
            .task {
                await viewModel.loadTeams()
            }
        }
    }
}
