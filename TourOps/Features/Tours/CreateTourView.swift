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

    /// Teams the user can choose from. Empty when the tour is created from a
    /// specific team, in which case `teamID` is used as is.
    let teamChoices: [PickerOption]

    @State private var draft = TourDraft()

    /// Fixed for the lifetime of the form, so a second submission could never
    /// store a second tour.
    @State private var tourID = UUID()

    @State private var selectedTeamID: UUID
    @State private var gate = SubmissionGate()
    @State private var showingError = false

    init(
        viewModel: TourListViewModel,
        teamID: UUID,
        teamChoices: [PickerOption] = []
    ) {
        self.viewModel = viewModel
        self.teamID = teamID
        self.teamChoices = teamChoices

        _selectedTeamID = State(initialValue: teamID)
    }

    var body: some View {
        FormSheet(
            title: "New tour",
            saveTitle: "Save tour",
            canSave: draft.isValid(),
            isSaving: gate.isRunning,
            onCancel: { dismiss() },
            onSave: submit
        ) {
            TourFormContent(
                draft: $draft,
                teamChoices: teamChoices,
                teamSelection: $selectedTeamID
            )
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
            let tour = draft.newTour(id: tourID, teamID: selectedTeamID)
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
#Preview("Empty, light") {
    CreateTourView(
        viewModel: TourListViewModel(repository: PreviewTourRepository()),
        teamID: PreviewData.teamID
    )
    .preferredColorScheme(.light)
}

#Preview("Empty, dark") {
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
    .dynamicTypeSize(.accessibility3)
}
#endif
