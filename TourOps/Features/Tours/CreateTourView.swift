//
//  CreateTourView.swift
//  TourOps
//
//  Created by Damoon saber on 6/4/1405 AP.
//

import SwiftUI

struct CreateTourView: View {

    @Environment(\.dismiss) private var dismiss

    let viewModel: TourListViewModel
    let teamID: UUID

    @State private var draft = TourDraft()

    /// Fixed for the lifetime of the form, so a second submission could never
    /// store a second tour.
    @State private var tourID = UUID()

    @State private var gate = SubmissionGate()
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            ScreenScroll(topPadding: 24, spacing: 20) {
                TourFormContent(
                    draft: $draft,
                    title: "Create a tour",
                    subtitle: "Set a name and define the tour schedule."
                )
            }
            .navigationTitle("New Tour")
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
                        title: "Create",
                        isEnabled: draft.isValid(),
                        isSubmitting: gate.isRunning,
                        action: submit
                    )
                }
            }
        }
        .interactiveDismissDisabled(gate.isRunning)
        .alert(
            "Couldn’t Create Tour",
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
            let tour = draft.newTour(id: tourID, teamID: teamID)
        else {
            return
        }

        Task {
            let result = await gate.run({
                await viewModel.createTour(tour)
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
#Preview("Empty") {
    CreateTourView(
        viewModel: TourListViewModel(repository: PreviewTourRepository()),
        teamID: PreviewData.teamID
    )
    .preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
    CreateTourView(
        viewModel: TourListViewModel(repository: PreviewTourRepository()),
        teamID: PreviewData.teamID
    )
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}
#endif
