//
//  ShowDetailView.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import SwiftUI

struct ShowDetailView: View {

let showID: UUID
let viewModel: ShowListViewModel

@Environment(\.dismiss) private var dismiss

@State private var showingEditShow = false
@State private var showingDeleteConfirmation = false
@State private var showingError = false

private var show: Show? {
    viewModel.shows.first { $0.id == showID }
}

var body: some View {
    Group {
        if let show {

            Form {
                Section("Show Information") {
                    LabeledContent(
                        "Name",
                        value: show.name
                    )

                    LabeledContent(
                        "Venue",
                        value: show.venue
                    )

                    LabeledContent(
                        "City",
                        value: show.city
                    )

                    LabeledContent(
                        "Date",
                        value: show.date.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                }

                Section("Created") {
                    Text(
                        show.createdAt,
                        style: .date
                    )
                }

                Section {
                    Button(
                        "Delete Show",
                        role: .destructive
                    ) {
                        showingDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle(show.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .primaryAction
                ) {
                    Button("Edit") {
                        showingEditShow = true
                    }
                }
            }
            .sheet(
                isPresented: $showingEditShow
            ) {
                EditShowView(
                    viewModel: viewModel,
                    show: show
                )
            }

        } else {

            ContentUnavailableView(
                "Show Not Found",
                systemImage: "music.mic",
                description: Text(
                    "This show is no longer available."
                )
            )
        }
    }
    .confirmationDialog(
        "Delete Show?",
        isPresented: $showingDeleteConfirmation,
        titleVisibility: .visible
    ) {
        Button(
            "Delete",
            role: .destructive
        ) {
            guard let show else {
                return
            }

            Task {
                let success =
                    await viewModel.deleteShow(show)

                if success {
                    dismiss()
                } else {
                    showingError = true
                }
            }
        }

        Button(
            "Cancel",
            role: .cancel
        ) {
        }
    } message: {
        Text("This action cannot be undone.")
    }
    .alert(
        "Error",
        isPresented: $showingError
    ) {
        Button(
            "OK",
            role: .cancel
        ) {
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
