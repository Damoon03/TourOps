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

    @State private var draft = ShowDraft()

    /// Fixed for the lifetime of the form, so even if a second submission
    /// slipped through, the repository would reject it as a duplicate
    /// instead of storing two shows.
    @State private var showID = UUID()

    @State private var gate = SubmissionGate()
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            ScreenScroll(topPadding: 24, spacing: 20) {
                ShowFormContent(
                    draft: $draft,
                    title: "Add a show",
                    subtitle: "Add a venue, city, and schedule for this tour."
                )
            }
            .navigationTitle("New Show")
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
                        isEnabled: draft.isValid,
                        isSubmitting: gate.isRunning,
                        action: submit
                    )
                }
            }
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
            let show = draft.newShow(id: showID, tourID: tourID)
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
#Preview("Empty") {
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
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}
#endif
