//
//  CreateTeamView.swift
//  TourOps
//
//  Created by Damoon saber on 6/3/1405 AP.
//

import SwiftUI

struct CreateTeamView: View {

    @Environment(\.dismiss) private var dismiss

    let viewModel: TeamListViewModel

    @State private var draft = TeamDraft()

    /// Fixed for the lifetime of the form, so a second submission could never
    /// store a second team.
    @State private var teamID = UUID()

    @State private var isImageBusy = false
    @State private var gate = SubmissionGate()
    @State private var showingError = false

    private var canSubmit: Bool {
        draft.isValid && !isImageBusy
    }

    var body: some View {
        NavigationStack {
            ScreenScroll(topPadding: 24, spacing: 20) {
                TeamFormContent(
                    draft: $draft,
                    isImageBusy: $isImageBusy,
                    title: "Add an artist or band",
                    subtitle: "Set up the identity you’ll use to organize tours and shows."
                )
            }
            .navigationTitle("New Team")
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
                        isEnabled: canSubmit,
                        isSubmitting: gate.isRunning,
                        action: submit
                    )
                }
            }
        }
        .interactiveDismissDisabled(gate.isRunning)
        .alert(
            "Couldn’t Create Team",
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
            !isImageBusy,
            let team = draft.newTeam(id: teamID)
        else {
            return
        }

        Task {
            let result = await gate.run({
                await viewModel.createTeam(team)
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
    CreateTeamView(
        viewModel: TeamListViewModel(repository: PreviewTeamRepository())
    )
    .preferredColorScheme(.dark)
}

#Preview("Accessibility text size") {
    CreateTeamView(
        viewModel: TeamListViewModel(repository: PreviewTeamRepository())
    )
    .preferredColorScheme(.dark)
    .dynamicTypeSize(.accessibility3)
}
#endif
