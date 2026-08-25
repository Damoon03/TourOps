//
//  TeamListView.swift
//  TourOps
//
//  Created by Damoon saber on 5/31/1405 AP.
//

import SwiftUI

struct TeamListView: View {

    let repository: TeamRepositoryProtocol

    @State private var viewModel: TeamListViewModel
    @State private var showingCreateTeam = false

    init(repository: TeamRepositoryProtocol) {
        self.repository = repository
        _viewModel = State(
            initialValue: TeamListViewModel(
                repository: repository
            )
        )
    }

    var body: some View {
        NavigationStack {
            List(viewModel.teams) { team in
                VStack(alignment: .leading) {
                    Text(team.name)
                        .font(.headline)

                    Text("\(team.genre) • \(team.city)")
                        .font(.subheadline)
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
