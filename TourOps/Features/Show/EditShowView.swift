//
//  EditShowView.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import SwiftUI

struct EditShowView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: ShowListViewModel
    private let show: Show

    @State private var name: String
    @State private var venue: String
    @State private var city: String
    @State private var date: Date

    init(
        viewModel: ShowListViewModel,
        show: Show
    ) {
        self.viewModel = viewModel
        self.show = show

        _name = State(initialValue: show.name)
        _venue = State(initialValue: show.venue)
        _city = State(initialValue: show.city)
        _date = State(initialValue: show.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Show Information") {
                    TextField(
                        "Name",
                        text: $name
                    )

                    TextField(
                        "Venue",
                        text: $venue
                    )

                    TextField(
                        "City",
                        text: $city
                    )

                    DatePicker(
                        "Date",
                        selection: $date,
                        displayedComponents: [
                            .date,
                            .hourAndMinute
                        ]
                    )
                }
            }
            .navigationTitle("Edit Show")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Save") {
                        Task {
                            let updatedShow = Show(
                                id: show.id,
                                tourID: show.tourID,
                                name: name,
                                venue: venue,
                                city: city,
                                date: date,
                                createdAt: show.createdAt,
                                version: show.version
                            )

                            let success =
                                await viewModel.updateShow(
                                    updatedShow
                                )

                            if success {
                                dismiss()
                            }
                        }
                    }
                    .disabled(
                        name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                        || venue.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                        || city.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                    )
                }
            }
        }
    }
}

#Preview {
    Text("Edit Show Preview")
}
