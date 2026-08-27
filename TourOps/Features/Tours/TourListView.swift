//
//  TourListView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

struct TourListView: View {

let repository: TourRepositoryProtocol
let teamID: UUID
let showRepository: ShowRepositoryProtocol

@State private var viewModel: TourListViewModel
@State private var showingCreateTour = false

init(
    repository: TourRepositoryProtocol,
    teamID: UUID,
    showRepository: ShowRepositoryProtocol
) {
    self.repository = repository
    self.teamID = teamID
    self.showRepository = showRepository

    _viewModel = State(
        initialValue: TourListViewModel(
            repository: repository
        )
    )
}

private var teamTours: [Tour] {
    viewModel.tours.filter { $0.teamID == teamID }
}

var body: some View {

    Group {

        if viewModel.isLoading {

            ProgressView()

        } else if let errorMessage = viewModel.errorMessage {

            ContentUnavailableView(
                "Unable to Load Tours",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )

        } else if teamTours.isEmpty {

            ContentUnavailableView(
                "No Tours",
                systemImage: "music.note.list",
                description: Text(
                    "Create your first tour to get started."
                )
            )

        } else {

            List(teamTours) { tour in

                NavigationLink {

                    TourDetailView(
                        tourID: tour.id,
                        viewModel: viewModel,
                        showRepository: showRepository
                    )

                } label: {

                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {

                        Text(tour.name)
                            .font(.headline)

                        Text(
                            "\(tour.startDate.formatted(date: .abbreviated, time: .omitted)) – \(tour.endDate.formatted(date: .abbreviated, time: .omitted))"
                        )
                        .font(.subheadline)
                    }
                }
            }
        }
    }

    .navigationTitle("Tours")

    .toolbar {

        ToolbarItem(
            placement: .primaryAction
        ) {

            Button {

                showingCreateTour = true

            } label: {

                Image(systemName: "plus")
            }
        }
    }

    .sheet(
        isPresented: $showingCreateTour
    ) {

        CreateTourView(
            viewModel: viewModel,
            teamID: teamID
        )
    }

    .task {

        await viewModel.loadTours()
    }
}

}
