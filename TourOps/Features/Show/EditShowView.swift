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

    @State private var draft: ShowDraft
    @State private var gate = SubmissionGate()
    @State private var showingError = false

    init(
        viewModel: ShowListViewModel,
        show: Show
    ) {
        self.viewModel = viewModel
        self.show = show

        _draft = State(initialValue: ShowDraft(show: show))
    }

    var body: some View {
        FormSheet(
            title: "Edit show",
            saveTitle: "Save changes",
            canSave: draft.isValid,
            isSaving: gate.isRunning,
            onCancel: { dismiss() },
            onSave: submit
        ) {
            ShowFormContent(draft: $draft)
        }
        .interactiveDismissDisabled(gate.isRunning)
        .alert(
            "Couldn’t Update Show",
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
        guard
            !gate.isRunning,
            let updatedShow = draft.updatedShow(from: show)
        else {
            return
        }

        Task {
            let result = await gate.run({
                await viewModel.updateShow(updatedShow)
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
#Preview("Populated, light") {
    EditShowView(
        viewModel: ShowListViewModel(
            repository: PreviewShowRepository(shows: [PreviewData.upcomingShow])
        ),
        show: PreviewData.upcomingShow
    )
    .preferredColorScheme(.light)
}

#Preview("Populated, dark") {
    EditShowView(
        viewModel: ShowListViewModel(
            repository: PreviewShowRepository(shows: [PreviewData.upcomingShow])
        ),
        show: PreviewData.upcomingShow
    )
    .preferredColorScheme(.dark)
}

#Preview("Long text, large type") {
    EditShowView(
        viewModel: ShowListViewModel(
            repository: PreviewShowRepository(shows: [PreviewData.longShow])
        ),
        show: PreviewData.longShow
    )
    .dynamicTypeSize(.accessibility2)
}
#endif
