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
        NavigationStack {
            ScreenScroll(topPadding: 24, spacing: 20) {
                ShowFormContent(
                    draft: $draft,
                    title: "Edit show details",
                    subtitle: "Update the venue or adjust the schedule."
                )
            }
            .navigationTitle("Edit Show")
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
                        isEnabled: draft.isValid,
                        isSubmitting: gate.isRunning,
                        action: submit
                    )
                }
            }
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
#Preview("Populated") {
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
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility2)
}
#endif
