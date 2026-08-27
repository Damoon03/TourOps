//
//  ShowListView.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import SwiftUI

struct ShowListView: View {

let repository: ShowRepositoryProtocol
let tourID: UUID

@State private var viewModel: ShowListViewModel
@State private var showingCreateShow = false

init(
    repository: ShowRepositoryProtocol,
    tourID: UUID
) {
    self.repository = repository
    self.tourID = tourID

    _viewModel = State(
        initialValue: ShowListViewModel(
            repository: repository
        )
    )
}

private var tourShows: [Show] {
    viewModel.shows.filter { $0.tourID == tourID }
}

var body: some View {

    Group {

        if viewModel.isLoading {

            ProgressView()

        } else if let errorMessage = viewModel.errorMessage {

            ContentUnavailableView(
                "Unable to Load Shows",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )

        } else if tourShows.isEmpty {

            ContentUnavailableView(
                "No Shows",
                systemImage: "music.mic",
                description: Text(
                    "Create your first show to get started."
                )
            )

        } else {

            List(tourShows, id: \.id) { show in
                NavigationLink {
                    ShowDetailView(
                        showID: show.id,
                        viewModel: viewModel
                    )
                } label: {
                    VStack(
                        alignment: .leading,
                        spacing: 4
                    ) {
                        Text(show.name)
                            .font(.headline)

                        Text(show.venue)
                            .font(.subheadline)

                        Text(show.city)
                            .font(.subheadline)

                        Text(
                            show.date.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                        )
                        .font(.subheadline)
                    }
                }
            }
            }
    }

    .navigationTitle("Shows")

    .toolbar {

        ToolbarItem(
            placement: .primaryAction
        ) {

            Button {

                showingCreateShow = true

            } label: {

                Image(systemName: "plus")
            }
        }
    }

    .sheet(
        isPresented: $showingCreateShow
    ) {

        CreateShowView(
            viewModel: viewModel,
            tourID: tourID
        )
    }

    .task {

        await viewModel.loadShows()
    }
}

}
