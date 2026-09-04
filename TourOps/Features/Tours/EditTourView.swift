//
//  EditTourView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

struct EditTourView: View {
    @Environment(\.dismiss) private var dismiss

    let viewModel: TourListViewModel

    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date

    private let tour: Tour

    @State private var showingError = false

    init(
        viewModel: TourListViewModel,
        tour: Tour
    ) {
        self.viewModel = viewModel
        self.tour = tour

        _name = State(initialValue: tour.name)
        _startDate = State(initialValue: tour.startDate)
        _endDate = State(initialValue: tour.endDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tour Information") {
                    TextField("Name", text: $name)

                    DatePicker(
                        "Start Date",
                        selection: $startDate,
                        displayedComponents: .date
                    )

                    DatePicker(
                        "End Date",
                        selection: $endDate,
                        displayedComponents: .date
                    )
                }
            }
            .navigationTitle("Edit Tour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let updatedTour = Tour(
                                id: tour.id,
                                teamID: tour.teamID,
                                name: name,
                                startDate: startDate,
                                endDate: endDate,
                                createdAt: tour.createdAt,
                                version: tour.version
                            )

                            let success = await viewModel.updateTour(
                                updatedTour
                            )

                            if success {
                                dismiss()
                            } else {
                                showingError = true
                            }
                        }
                    }
                    .disabled(
                        name.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                        || endDate < startDate
                    )
                }
            }
            .alert(
                "Error",
                isPresented: $showingError
            ) {
                Button("OK", role: .cancel) {
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
}
