//
//  CreateShowView.swift
//  TourOps
//
//  Created by Damoon saber on 6/5/1405 AP.
//

import SwiftUI

struct CreateShowView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: ShowListViewModel
    let tourID: UUID

    @State private var name = ""
    @State private var venue = ""
    @State private var city = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Show Information") {
                    TextField("Name", text: $name)
                    TextField("Venue", text: $venue)
                    TextField("City", text: $city)

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
            .navigationTitle("New Show")
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
                            let show = Show(
                                id: UUID(),
                                tourID: tourID,
                                name: name,
                                venue: venue,
                                city: city,
                                date: date,
                                createdAt: Date(),
                                version: 1
                            )

                            let success = await viewModel.createShow(show)

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
    // Preview will be configured with the app's dependencies later.
    Text("Create Show Preview")
}
