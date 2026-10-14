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
    private let tour: Tour

    @State private var draft: TourDraft
    @State private var gate = SubmissionGate()
    @State private var showingError = false

    init(
        viewModel: TourListViewModel,
        tour: Tour
    ) {
        self.viewModel = viewModel
        self.tour = tour

        _draft = State(initialValue: TourDraft(tour: tour))
    }

    var body: some View {
        NavigationStack {
            ScreenScroll(topPadding: 24, spacing: 20) {
                TourFormContent(
                    draft: $draft,
                    title: "Edit tour details",
                    subtitle: "Update the tour name or schedule."
                )
            }
            .navigationTitle("Edit Tour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(gate.isRunning)
                }

                ToolbarItem(placement: .confirmationAction) {
                    SubmitButton(
                        title: "Save",
                        isEnabled: draft.isValid(),
                        isSubmitting: gate.isRunning,
                        action: submit
                    )
                }
            }
        }
        .interactiveDismissDisabled(gate.isRunning)
        .alert(
            "Couldn’t Update Tour",
            isPresented: $showingError
        ) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Something went wrong.")
        }
    }

    private func submit() {
        guard
            !gate.isRunning,
            let updatedTour = draft.updatedTour(from: tour)
        else {
            return
        }

        Task {
            let result = await gate.run({
                await viewModel.updateTour(updatedTour)
            })

            switch result {
            case .some(true):
                dismiss()
            case .some(false):
                showingError = true
            case .none:
                break
            }
        }
    }
}

#if DEBUG
#Preview("Populated") {
    EditTourView(
        viewModel: TourListViewModel(
            repository: PreviewTourRepository(tours: [PreviewData.upcomingTour])
        ),
        tour: PreviewData.upcomingTour
    )
    .preferredColorScheme(.dark)
}

#Preview("Long text, large type") {
    EditTourView(
        viewModel: TourListViewModel(
            repository: PreviewTourRepository(tours: [PreviewData.longTour])
        ),
        tour: PreviewData.longTour
    )
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
#endif
