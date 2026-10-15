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

    /// Tours the user can choose from. Empty when the show is created from a
    /// specific tour, in which case `tourID` is used as is.
    let tourChoices: [PickerOption]

    @State private var draft = ShowDraft()

    /// Fixed for the lifetime of the form, so even if a second submission
    /// slipped through, the repository would reject it as a duplicate
    /// instead of storing two shows.
    @State private var showID = UUID()

    @State private var selectedTourID: UUID
    @State private var gate = SubmissionGate()
    @State private var showingError = false

    init(
        viewModel: ShowListViewModel,
        tourID: UUID,
        tourChoices: [PickerOption] = []
    ) {
        self.viewModel = viewModel
        self.tourID = tourID
        self.tourChoices = tourChoices

        _selectedTourID = State(initialValue: tourID)
    }

    var body: some View {
        FormSheet(
            title: "New show",
            saveTitle: "Save show",
            canSave: draft.isValid,
            isSaving: gate.isRunning,
            onCancel: { dismiss() },
            onSave: submit
        ) {
            ShowFormContent(
                draft: $draft,
                tourChoices: tourChoices,
                tourSelection: $selectedTourID
            )
        }
        .interactiveDismissDisabled(gate.isRunning)
        .alert(
            "Couldn’t Create Show",
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

    private func submit() {
        // Revalidate here, not only in the button's disabled state.
        guard
            !gate.isRunning,
            let show = draft.newShow(id: showID, tourID: selectedTourID)
        else {
            return
        }

        Task {
            let result = await gate.run({
                await viewModel.createShow(show)
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
    CreateShowView(
        viewModel: ShowListViewModel(repository: PreviewShowRepository()),
        tourID: PreviewData.tourID
    )
    .preferredColorScheme(.light)
}

#Preview("Empty, dark") {
    CreateShowView(
        viewModel: ShowListViewModel(repository: PreviewShowRepository()),
        tourID: PreviewData.tourID
    )
    .preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
    CreateShowView(
        viewModel: ShowListViewModel(repository: PreviewShowRepository()),
        tourID: PreviewData.tourID
    )
    .dynamicTypeSize(.accessibility3)
}
#endif
